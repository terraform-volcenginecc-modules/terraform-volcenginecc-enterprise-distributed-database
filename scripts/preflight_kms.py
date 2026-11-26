#!/usr/bin/env python3
"""只读核对主栈引用的外部 KMS Key / Read-only validation for the external KMS Key."""

import argparse
import json
import re
import sys

from cloud_api import query


TRN_PATTERN = re.compile(
    r"^trn:kms:(?P<region>[^:]+):(?P<account>[0-9]+):"
    r"keyrings/(?P<keyring>[^/]+)/keys/(?P<key>[^/]+)$"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", required=True)
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--key-id", required=True)
    parser.add_argument("--key-trn", required=True)
    args = parser.parse_args()

    errors = []
    match = TRN_PATTERN.fullmatch(args.key_trn)
    if not match:
        errors.append("KMS Key TRN format is invalid")
    else:
        if match.group("region") != args.region:
            errors.append("KMS Key TRN region does not match --region")
        if match.group("account") != args.account_id:
            errors.append("KMS Key TRN account does not match --account-id")

    key = {}
    request_error = None
    try:
        response = query(
            args.region,
            "kms",
            "2021-02-18",
            "DescribeKey",
            {"KeyID": args.key_id},
            "GET",
        )
        key = response.get("Key", {})
    except (RuntimeError, OSError) as exc:
        request_error = type(exc).__name__
        errors.append("DescribeKey failed")

    if key:
        checks = {
            "id_matches": key.get("ID") == args.key_id,
            "trn_matches": key.get("Trn") == args.key_trn,
            "enabled": key.get("KeyState") == "Enable",
            "symmetric_256": key.get("KeySpec") == "SYMMETRIC_256",
            "encrypt_decrypt": key.get("KeyUsage") == "ENCRYPT_DECRYPT",
        }
        errors.extend(
            f"External KMS check failed: {name}"
            for name, passed in checks.items()
            if not passed
        )
    else:
        checks = {
            "id_matches": False,
            "trn_matches": False,
            "enabled": False,
            "symmetric_256": False,
            "encrypt_decrypt": False,
        }

    report = {
        "read_only": True,
        "passed": not errors,
        "region": args.region,
        "account_id": args.account_id,
        "key_id": args.key_id,
        "key_trn": args.key_trn,
        "keyring_name": match.group("keyring") if match else None,
        "key_name": match.group("key") if match else None,
        "checks": checks,
        "key_state": key.get("KeyState"),
        "request_error": request_error,
        "errors": errors,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
