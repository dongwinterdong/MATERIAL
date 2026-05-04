#!/usr/bin/env bash
# 一键 clone + git lfs pull + 合并 .ravi 分片（Linux / macOS）
#
# 用法：
#   ./pull-and-merge.sh                    # 默认在当前目录下 clone 到 ./MATERIAL
#   ./pull-and-merge.sh -s                 # 在已 clone 的仓库目录里跑（跳过 clone）
#   ./pull-and-merge.sh -d /data/MATERIAL  # 自定义目标目录
#   ./pull-and-merge.sh -u <repo-url>      # 自定义仓库 URL
#
# 环境变量同样支持：REPO_URL / DEST_DIR / OUTPUT_NAME / EXPECTED_SHA256

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/dongwinterdong/MATERIAL.git}"
DEST_DIR="${DEST_DIR:-MATERIAL}"
OUTPUT_NAME="${OUTPUT_NAME:-2023.03.27 70mm 1500 0.5 1.ravi}"
SKIP_CLONE=0

while getopts "su:d:h" opt; do
  case "$opt" in
    s) SKIP_CLONE=1 ;;
    u) REPO_URL="$OPTARG" ;;
    d) DEST_DIR="$OPTARG" ;;
    h)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) exit 2 ;;
  esac
done

# ANSI 颜色（不在 TTY 时关闭）
if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_GRAY=$'\033[90m'; C_OFF=$'\033[0m'
else
  C_CYAN=''; C_GREEN=''; C_GRAY=''; C_OFF=''
fi
say()  { printf '%s%s%s\n' "$C_CYAN"  "$1" "$C_OFF"; }
ok()   { printf '%s%s%s\n' "$C_GREEN" "$1" "$C_OFF"; }
dim()  { printf '%s%s%s\n' "$C_GRAY"  "$1" "$C_OFF"; }

command -v git >/dev/null 2>&1 || { echo "git 未安装" >&2; exit 1; }
git lfs version >/dev/null 2>&1 || {
  cat >&2 <<EOF
git-lfs 未安装。请先安装：
  Debian/Ubuntu : sudo apt install git-lfs
  CentOS/RHEL   : sudo yum install git-lfs
  Fedora        : sudo dnf install git-lfs
  Arch          : sudo pacman -S git-lfs
  macOS         : brew install git-lfs
然后执行：git lfs install
EOF
  exit 1
}

if [ "$SKIP_CLONE" -eq 0 ]; then
  say ">>> [1/4] 启用 Git LFS hooks"
  git lfs install

  if [ -e "$DEST_DIR" ]; then
    echo "目标目录 $DEST_DIR 已存在；删除它，或加 -s 在该目录里运行（跳过 clone）。" >&2
    exit 1
  fi

  say ">>> [2/4] 克隆 $REPO_URL -> $DEST_DIR （仅拉指针 < 10 MB）"
  GIT_LFS_SKIP_SMUDGE=1 git clone --progress "$REPO_URL" "$DEST_DIR"
  cd "$DEST_DIR"
else
  dim "跳过 clone（-s）"
  [ -d .git ] || { echo "当前目录不是 git 仓库根（找不到 .git）" >&2; exit 1; }
fi

say ">>> [3/4] 下载 LFS 对象（约 10 GB，自带进度条）"
git lfs pull

say ">>> [4/4] 合并 .ravi 分片"
if [ -f ./merge-ravi.sh ]; then
  bash ./merge-ravi.sh "$OUTPUT_NAME"
else
  shopt -s nullglob
  parts=("$OUTPUT_NAME".part??)
  shopt -u nullglob
  [ ${#parts[@]} -gt 0 ] || { echo "找不到分片：$OUTPUT_NAME.partNN" >&2; exit 1; }
  cat "$OUTPUT_NAME".part?? > "$OUTPUT_NAME"
fi

if [ -n "${EXPECTED_SHA256:-}" ]; then
  say ">>> 校验 SHA-256"
  actual=$(sha256sum "$OUTPUT_NAME" | awk '{print $1}')
  if [ "$actual" = "$EXPECTED_SHA256" ]; then
    ok "SHA-256 OK"
  else
    echo "SHA-256 不匹配！期望 $EXPECTED_SHA256，实际 $actual" >&2
    exit 2
  fi
fi

ok "全部完成。"
