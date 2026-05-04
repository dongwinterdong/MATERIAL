#!/usr/bin/env bash
# 把 "<OUTPUT>.partNN" 按字典序拼回 <OUTPUT>。
# 依赖：bash, cat, stat（Linux/macOS 通用）。
# 可选：pv（带进度条）、numfmt（人类可读大小）。

set -euo pipefail

OUTPUT_NAME="${1:-2023.03.27 70mm 1500 0.5 1.ravi}"

shopt -s nullglob
parts=("$OUTPUT_NAME".part??)
shopt -u nullglob

if [ ${#parts[@]} -eq 0 ]; then
  echo "Error: 在当前目录找不到 '$OUTPUT_NAME.partNN' 分片。" >&2
  exit 1
fi

stat_size() { stat -c%s "$1" 2>/dev/null || stat -f%z "$1"; }
fmt_size()  { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

total_expected=0
for p in "${parts[@]}"; do
  total_expected=$((total_expected + $(stat_size "$p")))
done

echo "Merging ${#parts[@]} parts -> $OUTPUT_NAME"
echo "  total expected: $(fmt_size "$total_expected")"

if command -v pv >/dev/null 2>&1; then
  pv -s "$total_expected" "${parts[@]}" > "$OUTPUT_NAME"
else
  : > "$OUTPUT_NAME"
  total=0
  for p in "${parts[@]}"; do
    sz=$(stat_size "$p")
    cat "$p" >> "$OUTPUT_NAME"
    total=$((total + sz))
    printf "  + %-48s %10s   total: %10s\n" \
      "$p" "$(fmt_size "$sz")" "$(fmt_size "$total")"
  done
fi

actual=$(stat_size "$OUTPUT_NAME")
if [ "$actual" -ne "$total_expected" ]; then
  echo "Error: 大小不匹配。期望 $total_expected，实际 $actual" >&2
  exit 2
fi

echo "Done: $OUTPUT_NAME ($(fmt_size "$actual"))"
