#!/usr/bin/env python3
"""手动验收使用的签名 API 客户端 / Signed API client for manual acceptance."""
import datetime as dt
import hashlib
import hmac
import json
import os
import urllib.error
import urllib.parse
import urllib.request


class CloudAPIError(RuntimeError):
    """Expose service codes/request IDs without retaining response bodies."""

    def __init__(self, action, code, request_id=None):
        super().__init__(f"{action}: {code}")
        self.code = str(code)
        self.request_id = request_id


def query(region, service, version, action, payload, method="POST", credentials=None, host=None,
          metadata_callback=None):
    """Never log credentials, headers or service messages that may echo secrets."""
    creds = credentials or {
        "AccessKeyId": os.environ.get("VOLCENGINE_ACCESS_KEY"),
        "SecretAccessKey": os.environ.get("VOLCENGINE_SECRET_KEY"),
        "SessionToken": os.environ.get("VOLCENGINE_SESSION_TOKEN"),
    }
    if not creds.get("AccessKeyId") or not creds.get("SecretAccessKey"):
        raise RuntimeError("Missing cloud credentials")
    host = host or f"{service}.{region}.volcengineapi.com"
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    params = {"Action": action, "Version": version}
    if method == "GET":
        params.update(payload)
    qs = urllib.parse.urlencode(sorted(params.items()), quote_via=urllib.parse.quote)
    body = json.dumps(payload, separators=(",", ":")).encode() if method == "POST" else b""
    digest = hashlib.sha256(body).hexdigest()
    headers = {"content-type": "application/json", "host": host, "x-date": now, "x-content-sha256": digest}
    if creds.get("SessionToken"):
        headers["x-security-token"] = creds["SessionToken"]
    names = ";".join(sorted(headers))
    canonical = "\n".join([
        method, "/", qs, "".join(f"{k}:{headers[k]}\n" for k in sorted(headers)), names, digest
    ])
    scope = f"{now[:8]}/{region}/{service}/request"
    to_sign = "\n".join(["HMAC-SHA256", now, scope, hashlib.sha256(canonical.encode()).hexdigest()])
    signing_key = creds["SecretAccessKey"].encode()
    for value in [now[:8], region, service, "request"]:
        signing_key = hmac.new(signing_key, value.encode(), hashlib.sha256).digest()
    signature = hmac.new(signing_key, to_sign.encode(), hashlib.sha256).hexdigest()
    headers["Authorization"] = (
        f"HMAC-SHA256 Credential={creds['AccessKeyId']}/{scope}, SignedHeaders={names}, Signature={signature}"
    )
    request = urllib.request.Request(f"https://{host}/?{qs}", data=body if method == "POST" else None, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            result = json.load(response)
    except urllib.error.HTTPError as exc:
        try:
            result = json.loads(exc.read())
        except (ValueError, UnicodeError):
            raise RuntimeError(f"{action}: HTTP {exc.code}") from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"{action}: transport {type(exc.reason).__name__}") from None
    metadata = result.get("ResponseMetadata", {})
    if metadata_callback is not None:
        metadata_callback({
            "action": action, "region": region, "host": host, "method": method,
            "request_id": metadata.get("RequestId"),
            "error_code": (metadata.get("Error") or {}).get("Code"),
        })
    error = metadata.get("Error")
    if error:
        raise CloudAPIError(action, error.get("Code", "ServiceError"),
                            result.get("ResponseMetadata", {}).get("RequestId")) from None
    if not isinstance(result.get("Result"), dict):
        raise RuntimeError(f"{action}: missing structured Result")
    return result["Result"]
