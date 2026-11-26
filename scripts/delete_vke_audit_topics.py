#!/usr/bin/env python3
"""Delete VKE-derived audit topics from one dedicated TLS project during destroy."""

import json
import os
import sys


def main() -> int:
    project_id = os.environ.get("TLS_PROJECT_ID", "").strip()
    region = os.environ.get("VOLCENGINE_REGION", "").strip()
    if not project_id or not region:
        raise RuntimeError("TLS_PROJECT_ID and VOLCENGINE_REGION are required")

    try:
        from volcengine.tls.TLSService import TLSService
        from volcengine.tls.tls_exception import TLSException
        from volcengine.tls.tls_requests import (
            DeleteTopicRequest,
            DescribeTopicsRequest,
        )
    except ImportError as exc:
        raise RuntimeError(
            "自动准备的生命周期环境缺少 TLS SDK"
        ) from exc

    service = TLSService(
        f"https://tls-{region}.volces.com",
        os.environ["VOLCENGINE_ACCESS_KEY"],
        os.environ["VOLCENGINE_SECRET_KEY"],
        region,
        security_token=os.environ.get("VOLCENGINE_SESSION_TOKEN"),
        timeout=25,
    )
    try:
        response = service.describe_topics(
            DescribeTopicsRequest(project_id=project_id, page_size=100)
        ).response
    except TLSException as exc:
        if getattr(exc, "http_code", None) == 404:
            print(json.dumps({"project_absent": True, "deleted": []}))
            return 0
        raise

    topics = response.get("Topics") or response.get("TopicInfos") or []
    derived = [
        item
        for item in topics
        if str(item.get("TopicName", "")).startswith("vke-audit-")
    ]
    for item in derived:
        service.delete_topic(
            DeleteTopicRequest(topic_id=item["TopicId"])
        )

    remaining_response = service.describe_topics(
        DescribeTopicsRequest(project_id=project_id, page_size=100)
    ).response
    remaining = (
        remaining_response.get("Topics")
        or remaining_response.get("TopicInfos")
        or []
    )
    remaining_derived = [
        item
        for item in remaining
        if str(item.get("TopicName", "")).startswith("vke-audit-")
    ]
    if remaining_derived:
        raise RuntimeError("VKE-derived TLS topics remain after deletion")

    print(
        json.dumps(
            {
                "project_id": project_id,
                "deleted": [
                    {
                        "topic_id": item["TopicId"],
                        "topic_name": item["TopicName"],
                    }
                    for item in derived
                ],
                "remaining_derived": 0,
            },
            ensure_ascii=True,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(
            json.dumps(
                {
                    "error_type": type(exc).__name__,
                    "message": str(exc),
                },
                ensure_ascii=True,
            ),
            file=sys.stderr,
        )
        raise
