#!/usr/bin/env python3
"""Idempotently create and verify cluster-owned VKE Required addons."""

import hashlib
import json
import os
import re
import time

from cloud_api import query


ALLOWED_ADDONS = {"core-dns", "metrics-server"}


def version_key(value):
    match = re.fullmatch(
        r"v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?", value
    )
    if not match:
        raise ValueError("Unsupported Kubernetes version syntax.")
    major, minor, patch, suffix = match.groups()
    identifiers = tuple(
        (0, int(part)) if part.isdigit() else (1, part)
        for part in (suffix or "").split(".")
    )
    return (int(major), int(minor), int(patch or 0), suffix is None, identifiers)


def compatible(actual, expression):
    try:
        current = version_key(actual)
    except ValueError:
        return False
    outcomes = []
    for alternative in expression.split("||"):
        tokens = alternative.split()
        if not tokens:
            return False
        accepted = True
        for token in tokens:
            bound = re.fullmatch(
                r"(>=|<=|>|<|=)?(v?\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z.-]+)?)",
                token,
            )
            if not bound:
                return False
            operator, value = bound.groups()
            target = version_key(value)
            checks = {
                ">=": current >= target,
                "<=": current <= target,
                ">": current > target,
                "<": current < target,
                "=": current == target,
            }
            accepted = accepted and checks[operator or "="]
        outcomes.append(accepted)
    return any(outcomes)


def emit(status, **details):
    print(
        json.dumps({"required_addons": status, **details}, sort_keys=True),
        flush=True,
    )


def reconcile(region, cluster_id, desired, timeout=1200, api=query):
    if not re.fullmatch(r"[a-z]{2}-[a-z0-9-]+", region):
        raise RuntimeError("Invalid region.")
    if not re.fullmatch(r"[A-Za-z0-9-]+", cluster_id):
        raise RuntimeError("Invalid cluster ID.")
    if not isinstance(desired, dict) or set(desired) != ALLOWED_ADDONS:
        raise RuntimeError("Required addon set must be core-dns and metrics-server.")
    if not 300 <= timeout <= 3600:
        raise RuntimeError("Timeout must be 300..3600 seconds.")
    for name, target in desired.items():
        if (
            not isinstance(target, dict)
            or not isinstance(target.get("version"), str)
            or not target["version"].strip()
        ):
            raise RuntimeError(f"{name}: explicit version is required.")
        if target.get("deploy_mode") not in {"Managed", "Unmanaged"}:
            raise RuntimeError(f"{name}: invalid deployment mode.")
        node_type = target.get("deploy_node_type")
        if target["deploy_mode"] == "Managed" and node_type is not None:
            raise RuntimeError(f"{name}: Managed addons must omit node type.")
        if (
            target["deploy_mode"] == "Unmanaged"
            and node_type not in {"Node", "VirtualNode"}
        ):
            raise RuntimeError(f"{name}: Unmanaged addons require a node type.")

    deadline = time.monotonic() + timeout

    def call(action, payload):
        if deadline - time.monotonic() <= 0:
            raise RuntimeError("Required addon reconciliation timed out.")
        return api(region, "vke", "2022-05-12", action, payload)

    clusters = call(
        "ListClusters", {"Filter": {"Ids": [cluster_id]}}
    ).get("Items", [])
    if (
        not isinstance(clusters, list)
        or len(clusters) != 1
        or clusters[0].get("Id") != cluster_id
        or clusters[0].get("Status", {}).get("Phase") != "Running"
    ):
        raise RuntimeError("Expected one Running target cluster.")
    kubernetes = clusters[0]["KubernetesVersion"]

    for name, target in sorted(desired.items()):
        items = call(
            "ListSupportedAddons",
            {"Filter": {"Name": name, "PodNetworkModes": ["VpcCniShared"]}},
        ).get("Items", [])
        if (
            not isinstance(items, list)
            or len(items) != 1
            or items[0].get("Name") != name
            or items[0].get("Necessary") != "Required"
        ):
            raise RuntimeError(
                f"{name}: expected exactly one Required addon contract."
            )
        contract = items[0]
        deploy_modes = contract.get("DeployModes") or [
            contract.get("DeployMode")
        ]
        if target["deploy_mode"] not in deploy_modes:
            raise RuntimeError(f"{name}: requested deploy mode is unsupported.")
        versions = {
            item["Version"]: item for item in contract.get("Versions", [])
        }
        version = versions.get(target["version"])
        if not version:
            raise RuntimeError(f"{name}: requested version is unsupported.")
        constraints = version.get("Compatibilities")
        if not isinstance(constraints, list):
            raise RuntimeError(f"{name}: missing version compatibility metadata.")
        if constraints and not any(
            compatible(kubernetes, item["KubernetesVersion"])
            for item in constraints
        ):
            raise RuntimeError(f"{name}: requested version is not compatible.")
        emit(
            "SUPPORTED",
            name=name,
            compatibility=(
                "matched" if constraints else "service_declares_no_constraint"
            ),
        )

    def inventory():
        result = []
        page = 1
        while True:
            batch = call(
                "ListAddons",
                {
                    "Filter": {"ClusterIds": [cluster_id]},
                    "PageNumber": page,
                    "PageSize": 100,
                },
            ).get("Items")
            if not isinstance(batch, list):
                raise RuntimeError("ListAddons returned no Items array.")
            result.extend(batch)
            if len(batch) < 100:
                index = {}
                for item in result:
                    if item.get("ClusterId") != cluster_id:
                        raise RuntimeError(
                            "ListAddons returned an addon from another cluster."
                        )
                    if item["Name"] in index:
                        raise RuntimeError(
                            "ListAddons returned duplicate addon names."
                        )
                    index[item["Name"]] = item
                return index
            page += 1

    def verify(name, addon, target):
        if (
            addon.get("Version") != target["version"]
            or addon.get("DeployMode") != target["deploy_mode"]
            or (
                target["deploy_mode"] == "Unmanaged"
                and addon.get("DeployNodeType")
                != target["deploy_node_type"]
            )
        ):
            raise RuntimeError(
                f"{name}: existing version or deployment settings differ; "
                "no implicit update."
            )
        phase = addon.get("Status", {}).get("Phase")
        if phase not in {"Running", "Creating", "Updating"}:
            raise RuntimeError(f"{name}: unsafe or unknown addon phase.")
        if phase == "Running":
            conditions = addon.get("Status", {}).get("Conditions", [])
            if not conditions or not all(
                item.get("Type") == "Ok" for item in conditions
            ):
                raise RuntimeError(f"{name}: Running addon is not healthy (Ok).")
        return phase

    def wait(name, target):
        while time.monotonic() < deadline:
            addon = inventory().get(name)
            if addon and verify(name, addon, target) == "Running":
                return
            emit("WAIT", name=name)
            time.sleep(min(5, max(0, deadline - time.monotonic())))
        raise RuntimeError(f"{name}: did not reach Running before timeout.")

    existing = inventory()
    for name, target in sorted(desired.items()):
        if name in existing:
            verify(name, existing[name], target)

    for name, target in sorted(desired.items()):
        addon = inventory().get(name)
        if addon:
            emit(
                "KEEP",
                name=name,
                version=target["version"],
                phase=verify(name, addon, target),
            )
            wait(name, target)
            continue
        payload = {
            "ClusterId": cluster_id,
            "Name": name,
            "Version": target["version"],
            "DeployMode": target["deploy_mode"],
            "ClientToken": hashlib.sha256(
                (
                    f"{cluster_id}|{name}|{target['version']}|"
                    f"{target['deploy_mode']}|"
                    f"{target.get('deploy_node_type')}"
                ).encode()
            ).hexdigest(),
        }
        emit("CREATE", name=name, version=target["version"])
        call("CreateAddon", payload)
        wait(name, target)

    for name, target in sorted(desired.items()):
        wait(name, target)
    emit("RUNNING", addons=sorted(desired), cluster_id=cluster_id)
    return 0


def main():
    return reconcile(
        os.environ.get("REQUIRED_ADDONS_REGION", ""),
        os.environ.get("REQUIRED_ADDONS_CLUSTER_ID", ""),
        json.loads(os.environ.get("REQUIRED_ADDONS_JSON", "{}")),
        int(os.environ.get("REQUIRED_ADDONS_TIMEOUT", "1200")),
    )


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        RuntimeError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        json.JSONDecodeError,
    ) as exc:
        emit("FAILED", reason=str(exc))
        raise SystemExit(1)
