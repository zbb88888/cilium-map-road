#!/usr/bin/env bash
# cilium 图路 · 一致性巡检脚本
# 检查：对象数一致 / 链接 / mermaid fence / 读写箭头 / 覆盖矩阵 / 路文件数
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()   { printf '✅ %s\n' "$1"; }
bad()  { printf '❌ %s\n' "$1"; fail=1; }

# 1. 对象数一致（问2 头 == 问2 求和 == 问3 结论）
total=$(grep -oE '共 [0-9]+ 个去重核心对象' map/completeness.md | grep -oE '[0-9]+' | head -1)
sum=$(sed -n '/## 问 2/,/## 问 3/p' map/completeness.md \
      | grep -oE '\| [0-9]+ \|$' | grep -oE '[0-9]+' | paste -sd+ | bc)
conclusion=$(grep -oE '结论：[0-9]+ 个对象' map/completeness.md | grep -oE '[0-9]+')
if [ "${total:-}" = "${sum:-}" ] && [ "${sum:-}" = "${conclusion:-}" ]; then
  ok "对象数一致：$total"
else
  bad "对象数不一致：问2头=${total:-无} 问2求和=${sum:-无} 问3结论=${conclusion:-无}"
fi

# 2. broken links（map/road/README 内所有 .md 链接）
broken=0
while IFS= read -r f; do
  dir=$(dirname "$f")
  while IFS= read -r l; do
    [ -f "$dir/$l" ] || { printf '   broken: %s -> %s\n' "$f" "$l"; broken=1; }
  done < <(grep -oE '\]\([^)]*\.md\)' "$f" | sed 's/](//;s/)//')
done < <( { find map road -name '*.md'; echo README.md; } | sort )
[ "$broken" = 0 ] && ok "链接无 broken" || bad "存在 broken link"

# 3. mermaid fence 平衡（每个 md 的 ``` 数为偶数）
odd=0
while IFS= read -r f; do
  n=$(grep -c '```' "$f" || true)
  if [ $((n % 2)) -ne 0 ]; then printf '   odd fence: %s (%s)\n' "$f" "$n"; odd=1; fi
done < <( { find map road -name '*.md'; echo README.md; } | sort )
[ "$odd" = 0 ] && ok "mermaid fence 平衡" || bad "存在 fence 不平衡"

# 4. 读写箭头约定（启发式）：实线(-->)标读、虚线(..>/-.->)标写 视为违例
#    只检查含箭头符号的行，排除图例/修正说明行。
viol=0
while IFS= read -r line; do
  case "$line" in
    *'-->'*) if echo "$line" | grep -q '读' && ! echo "$line" | grep -q '写'; then printf '   实线标读: %s\n' "$line"; viol=1; fi ;;
  esac
done < <(grep -rhn -- '-->' map road README.md | grep -v '图例\|打磨\|修正\|实线\|虚线\|写者\|读者')
while IFS= read -r line; do
  case "$line" in
    *'..>'*|*'-.->'*) if echo "$line" | grep -q '写' && ! echo "$line" | grep -q '读'; then printf '   虚线标写: %s\n' "$line"; viol=1; fi ;;
  esac
done < <(grep -rhn -e '\.\.>' -e '-\.->' map road README.md | grep -v '图例\|打磨\|修正\|实线\|虚线\|写者\|读者')
[ "$viol" = 0 ] && ok "读写箭头约定（实写虚读）" || bad "存在读写箭头违例"

# 5. road 文件数 == 已有路表条目数
roadfiles=$(find road -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
roadrows=$(sed -n '/## 已有路/,/## 覆盖矩阵/p' road/README.md | grep -c '\.md)')
if [ "$roadfiles" = "$roadrows" ]; then ok "路文件数一致：$roadfiles"; else bad "路文件数($roadfiles) != 已有路表($roadrows)"; fi

# 6. 覆盖矩阵：计算每列 ✅ 数，与「覆盖计数」行对齐
check_matrix() {
  local start="$1" end="$2" cols="$3"
  local -a counts
  local i
  for ((i=1;i<=cols;i++)); do counts[i]=0; done
  local section
  section=$(sed -n "/$start/,/$end/p" road/README.md)
  # 逐数据行统计（跳过标题行与覆盖计数行）
  while IFS= read -r row; do
    case "$row" in
      '| 路 '*|'|---'*|'| **覆盖计数**'*|'') continue ;;
    esac
    # 去掉首尾 |，取第 2..cols+1 列
    local body; body=$(echo "$row" | sed 's/^|//;s/|$//')
    local c=1
    while IFS='|' read -r -a cells; do
      for ((c=1;c<=cols;c++)); do
        cell=$(echo "${cells[$c]:-}" | tr -d ' ')
        [ "$cell" = "✅" ] && counts[c]=$((counts[c]+1))
      done
    done <<< "$body"
  done < <(echo "$section")
  # 取覆盖计数行
  local crow
  crow=$(echo "$section" | grep '**覆盖计数**')
  local body2; body2=$(echo "$crow" | sed 's/^|//;s/|$//')
  IFS='|' read -r -a ccells <<< "$body2"
  for ((c=1;c<=cols;c++)); do
    local want; want=$(echo "${ccells[$c]:-}" | tr -d ' ')
    if [ "${counts[c]}" != "$want" ]; then
      printf '   矩阵列%d不匹配：实际=%d 标称=%s\n' "$c" "${counts[c]}" "$want"
      return 1
    fi
  done
  return 0
}
if check_matrix '## 覆盖矩阵（路 × 层）' '## 覆盖矩阵（路 × 组件）' 10; then
  ok "覆盖矩阵（路×层）计数对齐"
else
  bad "覆盖矩阵（路×层）计数不对齐"
fi
if check_matrix '## 覆盖矩阵（路 × 组件）' '## 待找路' 4; then
  ok "覆盖矩阵（路×组件）计数对齐"
else
  bad "覆盖矩阵（路×组件）计数不对齐"
fi

echo
if [ "$fail" = 0 ]; then echo "全部巡检通过 ✅"; else echo "巡检失败 ❌"; fi
exit $fail
