#!/usr/bin/env python3
"""只读 VKE 区域预检，不代替 Terraform 创建资源 / Read-only VKE regional preflight."""
import argparse
import datetime as dt
import json
from pathlib import Path
import sys
from cloud_api import query


ADDONS = {
    "core_dns": "core-dns", "metrics_server": "metrics-server",
    "prometheus_agent": "prometheus-agent", "log_collector": "log-collector",
    "node_problem_detector": "node-problem-detector", "csi_ebs": "csi-ebs",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", default="cn-beijing")
    parser.add_argument("--zones", nargs="+", default=["cn-beijing-a", "cn-beijing-b", "cn-beijing-d"])
    parser.add_argument("--instance-types", nargs="+", default=["ecs.g3i.xlarge"])
    parser.add_argument("--image-id", help="Optional exact image ID to check")
    parser.add_argument("--kubernetes-version", default="1.32")
    parser.add_argument("--addon-versions-json", type=Path,
                        help="JSON object containing the six addon_versions selections")
    parser.add_argument("--catalog-only", action="store_true",
                        help="List compatible choices without claiming deployment readiness")
    args = parser.parse_args()
    selected = {}
    if args.addon_versions_json:
        try:
            selected = json.loads(args.addon_versions_json.read_text())
        except (OSError, ValueError):
            parser.error("Cannot read addon versions JSON")
        if not isinstance(selected, dict) or any(
            key not in ADDONS or not isinstance(value, str) or not value
            for key, value in selected.items()
        ):
            parser.error("Addon versions must map the six Terraform addon keys to nonempty strings")
    report = {
        "read_only": True, "queried_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "region": args.region, "results": {}, "errors": [],
        "scope": "catalog_only" if args.catalog_only else "selected_image_and_addons",
        "selected_versions": selected, "required_addons": [],
        "selected_configuration_supported": False,
        "deployment_ready": False,
        "unchecked": ["cluster_version_creatable", "quotas", "service_roles", "business_authorization",
                      "required_addon_delete_support"],
    }
    if not args.catalog_only:
        if not args.image_id:
            report["errors"].append("An exact --image-id is required")
        for key in ADDONS:
            if key not in selected:
                report["errors"].append(f"Missing selected addon version: {key}")
    calls = [
        ("resources", "ListSupportedResourceTypes", {"Filter": {"ZoneIds": args.zones}, "PageSize": 100, "PageNumber": 1}),
        ("images", "ListSupportedImages", {"InstanceTypeIds": args.instance_types}),
    ] + [
        (name, "ListSupportedAddons", {"Filter": {
            "Name": name, "PodNetworkModes": ["VpcCniShared"],
            "Versions.Compatibilities.KubernetesVersions": [args.kubernetes_version],
        }})
        for name in ADDONS.values()
    ]
    for label, action, payload in calls:
        try:
            result = query(args.region, "vke", "2022-05-12", action, payload)
            if label == "resources":
                items = list(result.get("Items", []))
                page = 1
                while page * 100 < result.get("TotalCount", 0):
                    page += 1
                    result = query(args.region, "vke", "2022-05-12", action, dict(payload, PageNumber=page))
                    items.extend(result.get("Items", []))
                result = dict(result, Items=items)
            report["results"][label] = result
            if label == "resources":
                supported = {}
                for item in result.get("Items", []):
                    if item.get("ResourceType") == "Ecs":
                        supported.setdefault(item.get("ZoneId"), set()).update(item.get("ResourceSpecifications", []))
                for zone in args.zones:
                    for instance_type in args.instance_types:
                        if instance_type not in supported.get(zone, set()):
                            report["errors"].append(f"Unsupported ECS specification in {zone}: {instance_type}")
            elif label == "images" and args.image_id:
                for instance_type in args.instance_types:
                    images = {image.get("ImageId") for item in result.get("Items", []) if item.get("InstanceTypeId") == instance_type for image in item.get("SupportedImages", [])}
                    if args.image_id not in images:
                        report["errors"].append(f"Selected image is not supported for {instance_type}")
            elif label not in {"resources", "images"}:
                items = [item for item in result.get("Items", []) if item.get("Name") == label]
                versions = {version.get("Version") for item in items for version in item.get("Versions", [])}
                if not items or not versions:
                    report["errors"].append(f"No compatible addon version returned: {label}")
                key = next(key for key, name in ADDONS.items() if name == label)
                if key in selected and selected[key] not in versions:
                    report["errors"].append(f"Selected addon version is not compatible: {label}={selected[key]}")
                if any(item.get("Necessary") == "Required" for item in items):
                    report["required_addons"].append(label)
        except (RuntimeError, OSError) as exc:
            report["errors"].append(str(exc) if isinstance(exc, RuntimeError) else f"{action}: network unavailable")
    report["selected_configuration_supported"] = not args.catalog_only and not report["errors"]
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
