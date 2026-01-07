#!/bin/bash

# Nexus CLI 静态行为验证测试
# 验证 commands/nexus.md 的设计规格一致性

# 不使用 set -e，因为 grep 可能返回非零退出码

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NEXUS_FILE="$PROJECT_ROOT/commands/nexus.md"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Nexus CLI 静态行为验证测试 v4.0.0                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "测试目标: $NEXUS_FILE"
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# 辅助函数
pass() {
    echo "✅ PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "❌ FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-6: 阶段编号验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# TC-6.1: 验证没有负数阶段
if grep -qE "阶段 -[0-9]" "$NEXUS_FILE"; then
    fail "发现负数阶段编号"
else
    pass "没有负数阶段编号"
fi

# TC-6.1: 验证阶段 1-6 存在
for i in 1 2 3 4 5 6; do
    if grep -q "阶段 $i:" "$NEXUS_FILE" || grep -q "阶段 $i]" "$NEXUS_FILE"; then
        pass "阶段 $i 存在"
    else
        fail "缺少阶段 $i"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-1: Spec 流程强制执行 (FORCE_SPEC_FIRST)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证 FORCE_SPEC_FIRST 约束存在
if grep -q "FORCE_SPEC_FIRST" "$NEXUS_FILE"; then
    pass "FORCE_SPEC_FIRST 约束已定义"
else
    fail "缺少 FORCE_SPEC_FIRST 约束"
fi

# 验证 --skip-spec 标志文档
if grep -q "\-\-skip-spec" "$NEXUS_FILE"; then
    pass "--skip-spec 标志已文档化"
else
    fail "缺少 --skip-spec 文档"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-2: 用户确认强制执行 (FORCE_USER_CONFIRMATION)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证 FORCE_USER_CONFIRMATION 约束存在
if grep -q "FORCE_USER_CONFIRMATION" "$NEXUS_FILE"; then
    pass "FORCE_USER_CONFIRMATION 约束已定义"
else
    fail "缺少 FORCE_USER_CONFIRMATION 约束"
fi

# 验证 AskUserQuestion 调用次数 (应该至少 4 次)
ASK_COUNT=$(grep -c "AskUserQuestion" "$NEXUS_FILE" || echo "0")
if [ "$ASK_COUNT" -ge 4 ]; then
    pass "AskUserQuestion 调用充足 ($ASK_COUNT 次)"
else
    fail "AskUserQuestion 调用不足 ($ASK_COUNT 次, 期望 ≥4)"
fi

# 验证每个阶段的确认逻辑
if grep -q "需求审核" "$NEXUS_FILE"; then
    pass "阶段 1 需求确认存在"
else
    fail "缺少阶段 1 需求确认"
fi

if grep -q "设计审核" "$NEXUS_FILE"; then
    pass "阶段 2 设计确认存在"
else
    fail "缺少阶段 2 设计确认"
fi

if grep -q "任务审核" "$NEXUS_FILE"; then
    pass "阶段 3 任务确认存在"
else
    fail "缺少阶段 3 任务确认"
fi

if grep -q "执行器确认" "$NEXUS_FILE"; then
    pass "阶段 4 执行器确认存在"
else
    fail "缺少阶段 4 执行器确认"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-3: 原子任务强制执行 (FORCE_ATOMIC_TASKS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证 FORCE_ATOMIC_TASKS 约束存在
if grep -q "FORCE_ATOMIC_TASKS" "$NEXUS_FILE"; then
    pass "FORCE_ATOMIC_TASKS 约束已定义"
else
    fail "缺少 FORCE_ATOMIC_TASKS 约束"
fi

# 验证 ≤5分钟 要求
if grep -q "≤5分钟\|≤5min" "$NEXUS_FILE"; then
    pass "任务粒度要求 (≤5分钟) 已定义"
else
    fail "缺少任务粒度要求"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-4: 批次分组强制执行 (FORCE_BATCH_GROUPING)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证 FORCE_BATCH_GROUPING 约束存在
if grep -q "FORCE_BATCH_GROUPING" "$NEXUS_FILE"; then
    pass "FORCE_BATCH_GROUPING 约束已定义"
else
    fail "缺少 FORCE_BATCH_GROUPING 约束"
fi

# 验证批次格式示例
if grep -q "批次 1:" "$NEXUS_FILE"; then
    pass "批次格式示例存在"
else
    fail "缺少批次格式示例"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-5: TodoWrite 即时更新 (FORCE_BATCH_TODOWRITE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证 FORCE_BATCH_TODOWRITE 约束存在
if grep -q "FORCE_BATCH_TODOWRITE" "$NEXUS_FILE"; then
    pass "FORCE_BATCH_TODOWRITE 约束已定义"
else
    fail "缺少 FORCE_BATCH_TODOWRITE 约束"
fi

# 验证 TodoWrite 更新示例
TODOWRITE_COUNT=$(grep -c "TodoWrite" "$NEXUS_FILE" || echo "0")
if [ "$TODOWRITE_COUNT" -ge 5 ]; then
    pass "TodoWrite 示例充足 ($TODOWRITE_COUNT 次)"
else
    fail "TodoWrite 示例不足 ($TODOWRITE_COUNT 次)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-7: 执行器路由验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证三种执行器文档
if grep -q "Claude" "$NEXUS_FILE" && grep -q "Gemini" "$NEXUS_FILE" && grep -q "Codex" "$NEXUS_FILE"; then
    pass "三种执行器 (Claude/Gemini/Codex) 已文档化"
else
    fail "执行器文档不完整"
fi

# 验证 PAL clink 调用格式
if grep -q "mcp__pal__clink" "$NEXUS_FILE" || grep -q "PAL clink" "$NEXUS_FILE"; then
    pass "PAL clink 调用格式已文档化"
else
    fail "缺少 PAL clink 调用格式"
fi

# 验证前端/后端路由逻辑
if grep -q "前端.*Gemini\|Gemini.*前端" "$NEXUS_FILE"; then
    pass "前端 → Gemini 路由逻辑存在"
else
    fail "缺少前端 → Gemini 路由逻辑"
fi

if grep -q "后端.*Codex\|Codex.*后端\|API.*Codex\|Codex.*API" "$NEXUS_FILE"; then
    pass "后端 → Codex 路由逻辑存在"
else
    fail "缺少后端 → Codex 路由逻辑"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TC-8: 禁止行为验证"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证禁止行为示例存在
if grep -q "❌ 错误" "$NEXUS_FILE" || grep -q "禁止行为" "$NEXUS_FILE"; then
    pass "禁止行为示例已文档化"
else
    fail "缺少禁止行为示例"
fi

# 验证自检要求
if grep -q "违规检测自检\|自检" "$NEXUS_FILE"; then
    pass "违规自检要求已文档化"
else
    fail "缺少违规自检要求"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "附加验证: 文档结构完整性"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 验证版本号
if grep -q "v4.0.0" "$NEXUS_FILE"; then
    pass "版本号 v4.0.0 正确"
else
    fail "版本号不正确或缺失"
fi

# 验证正确执行示例
if grep -q "✅ 正确执行方式" "$NEXUS_FILE"; then
    pass "正确执行示例存在"
else
    fail "缺少正确执行示例"
fi

# 验证输出格式定义
if grep -q "## 输出格式" "$NEXUS_FILE"; then
    pass "输出格式已定义"
else
    fail "缺少输出格式定义"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                        测试结果汇总"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ 通过: $PASS_COUNT"
echo "  ❌ 失败: $FAIL_COUNT"
echo "  📊 总计: $((PASS_COUNT + FAIL_COUNT))"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "🎉 所有测试通过！Nexus CLI 设计规格一致。"
    exit 0
else
    echo "⚠️  存在 $FAIL_COUNT 个测试失败，请检查 nexus.md 文件。"
    exit 1
fi
