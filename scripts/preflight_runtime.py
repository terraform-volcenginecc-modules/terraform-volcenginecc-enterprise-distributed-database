#!/usr/bin/env python3
"""验证自动准备的生命周期 Python 和 SDK，不访问云资源。"""

import argparse
import json
from pathlib import Path
import subprocess
import sys


CHECK = """
import importlib.metadata
import json
import sys
from volcengine.tls.TLSService import TLSService
from volcengine.tls.tls_requests import DeleteTopicRequest, DescribeTopicsRequest
from volcengine.tls.tls_exception import TLSException
from volcengine.auth.SignerV4 import SignerV4
assert callable(TLSService.describe_topics) and callable(TLSService.delete_topic)
DeleteTopicRequest(topic_id="preflight-only")
DescribeTopicsRequest(project_id="preflight-only", page_size=100)
print(json.dumps({"python": sys.executable, "version": list(sys.version_info[:3]),
                  "volcengine": importlib.metadata.version("volcengine")}))
"""


def check_runtime(executable):
    path = Path(executable)
    if not path.is_absolute() or not path.is_file():
        raise RuntimeError("生命周期解释器必须是存在的 Python 绝对路径。")
    # 保留虚拟环境路径，解析符号链接会丢失环境内安装的依赖。
    try:
        result = subprocess.run(
            [str(path), "-c", CHECK], capture_output=True, text=True, timeout=30
        )
    except (OSError, subprocess.TimeoutExpired):
        raise RuntimeError("无法在 30 秒内执行生命周期 Python。") from None
    if result.returncode:
        raise RuntimeError(
            "自动准备的生命周期 Python 无法导入 TLS SDK。"
        )
    try:
        report = json.loads(result.stdout)
        version = report["version"]
        sdk = report["volcengine"]
    except (ValueError, KeyError, TypeError):
        raise RuntimeError("生命周期 Python 返回了无效的环境检查结果。") from None
    if not isinstance(version, list) or version < [3, 12, 0]:
        raise RuntimeError("生命周期脚本要求 Python 3.12 或更高版本。")
    if sdk != "1.0.229":
        raise RuntimeError("生命周期 SDK 必须为固定版本 volcengine==1.0.229。")
    return {"passed": True, "read_only": True, **report}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python", required=True)
    args = parser.parse_args()
    try:
        report = check_runtime(args.python)
    except RuntimeError as exc:
        print(json.dumps({"passed": False, "error": str(exc)}), file=sys.stderr)
        return 1
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
