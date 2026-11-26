#!/bin/sh
# 自动准备 Python 和 SDK，供创建、销毁及可选预检共用。
set -eu
umask 077

if [ "$#" -eq 0 ] || [ ! -f "$1" ]; then
  printf '%s\n' '必须提供需要执行的 Python 脚本路径。' >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime_dir=$(mktemp -d "${TMPDIR:-/tmp}/数据库生命周期.XXXXXX")
staged_uv=
trap 'rm -rf "$runtime_dir"; if [ -n "$staged_uv" ]; then rm -f "$staged_uv"; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cache_dir="${XDG_CACHE_HOME:-${TMPDIR:-/tmp}}/数据库生命周期-$(id -u)"
mkdir -p "$cache_dir"
export UV_CACHE_DIR="$cache_dir/依赖缓存"
export UV_PYTHON_INSTALL_DIR="$cache_dir/Python工具"
export PYTHONDONTWRITEBYTECODE=1

download() {
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --retry 3 \
      --connect-timeout 20 --max-time 300 --output "$2" "$1"
  else
    wget --quiet --timeout=60 --tries=3 --output-document="$2" "$1"
  fi
}

# 固定版本并校验官方发行文件；首次执行不依赖系统 Python。
uv_version=0.11.32
has_expected_uv() {
  [ -n "$1" ] && [ -x "$1" ] || return 1
  case "$("$1" --version 2>/dev/null || true)" in
    "uv $uv_version"|"uv $uv_version "*) return 0 ;;
    *) return 1 ;;
  esac
}

uv_bin=$(command -v uv || true)
if ! has_expected_uv "$uv_bin"; then
  platform="$(uname -s)-$(uname -m)"
  case "$platform" in
    Darwin-arm64)
      wheel_url='https://files.pythonhosted.org/packages/60/43/ec2de11ef008e76a8d01c34d573c939c565694f72c0d008d200aa3a5eac3/uv-0.11.32-py3-none-macosx_11_0_arm64.whl'
      wheel_sha256=2a56d1abf16337350e878b2c869b256b8448ecc4a722b98f8d41e1b3680a587b
      ;;
    Darwin-x86_64)
      wheel_url='https://files.pythonhosted.org/packages/12/85/ef4d0f02f469cfad1d73c11bf31ac0a8f24da3c62d7f3305c50a5e51e814/uv-0.11.32-py3-none-macosx_10_12_x86_64.whl'
      wheel_sha256=c82954b1bd507e767b1d996c2865ea3eb7d464a479ec0e4d60f0b8e2e07dee45
      ;;
    Linux-aarch64)
      wheel_url='https://files.pythonhosted.org/packages/5d/61/0d6a8ee5066385fce65a5ef57939b1f63e9ff955afa07fa423c3e7e0abdb/uv-0.11.32-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.musllinux_1_1_aarch64.whl'
      wheel_sha256=125c142363d0842c8506a057da56bae182e2aa3957344f57dd9ef20ea10f06b0
      ;;
    Linux-x86_64)
      if ls /lib/ld-musl-* >/dev/null 2>&1; then
        wheel_url='https://files.pythonhosted.org/packages/02/58/0a92505cfe2b02b1c2d6ded23e83763fe98b43fbe1a4e5cbd6866da3bdf7/uv-0.11.32-py3-none-musllinux_1_1_x86_64.whl'
        wheel_sha256=77f4356548ee8dc47efae154efd4e930c65570e7d4971c57bdef592f6eefb39c
      else
        wheel_url='https://files.pythonhosted.org/packages/90/b0/114463d056b6b328d45557001e848b8ab15539bd8f4fa7a457ccb83e2b5d/uv-0.11.32-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
        wheel_sha256=3da76cd4e2697de30928b8a8524bd39183ac1e08cb7e72833807c022b7cba6c4
      fi
      ;;
    *)
      printf '当前执行环境不受支持：%s\n' "$platform" >&2
      exit 1
      ;;
  esac
  uv_bin="$cache_dir/uv-$uv_version-$platform"
  if ! has_expected_uv "$uv_bin"; then
    printf '%s\n' '正在自动下载生命周期运行工具。' >&2
    download "$wheel_url" "$runtime_dir/运行工具.whl"
    if command -v sha256sum >/dev/null 2>&1; then
      actual_sha256=$(sha256sum "$runtime_dir/运行工具.whl")
    elif command -v shasum >/dev/null 2>&1; then
      actual_sha256=$(shasum -a 256 "$runtime_dir/运行工具.whl")
    else
      actual_sha256=$(openssl dgst -sha256 -r "$runtime_dir/运行工具.whl")
    fi
    if [ "${actual_sha256%% *}" != "$wheel_sha256" ]; then
      printf '%s\n' '生命周期运行工具下载校验失败。' >&2
      exit 1
    fi
    unzip -p "$runtime_dir/运行工具.whl" "uv-$uv_version.data/scripts/uv" > "$runtime_dir/uv"
    chmod 700 "$runtime_dir/uv"
    # 同一执行账号并发调用时，各自下载后原子替换缓存文件。
    staged_uv=$(mktemp "$cache_dir/运行工具.XXXXXX")
    cp "$runtime_dir/uv" "$staged_uv"
    chmod 700 "$staged_uv"
    mv -f "$staged_uv" "$uv_bin"
    staged_uv=
  fi
fi

printf '%s\n' '正在自动准备 Python 3.12 和生命周期依赖。' >&2
"$uv_bin" --no-config --no-progress venv --no-project --python 3.12 \
  --managed-python "$runtime_dir/虚拟环境"
python_bin="$runtime_dir/虚拟环境/bin/python"
# 默认使用官方源；平台指定的源不可用时也会自动回退。
dependencies_installed=0
install_status=1
tried_indexes=
for package_index in \
  "${UV_DEFAULT_INDEX:-https://pypi.org/simple}" \
  "https://pypi.org/simple" \
  "https://mirrors.aliyun.com/pypi/simple/"; do
  case "|$tried_indexes" in
    *"|$package_index|"*) continue ;;
  esac
  tried_indexes="${tried_indexes}${package_index}|"
  if UV_HTTP_CONNECT_TIMEOUT=10 UV_HTTP_TIMEOUT=15 UV_HTTP_RETRIES=1 \
    "$uv_bin" --no-config --no-progress pip install --python "$python_bin" \
      --default-index "$package_index" -r "$script_dir/requirements.txt"; then
    dependencies_installed=1
    break
  else
    install_status=$?
    printf '%s\n' '当前依赖源安装失败，自动尝试备用源。' >&2
  fi
done
if [ "$dependencies_installed" -ne 1 ]; then
  printf '%s\n' '所有依赖源均安装失败，生命周期操作已停止。' >&2
  exit "$install_status"
fi
"$python_bin" "$script_dir/preflight_runtime.py" --python "$python_bin"
# 不使用 exec，确保实际脚本结束后清理临时环境，并原样传递退出码。
"$python_bin" "$@"
