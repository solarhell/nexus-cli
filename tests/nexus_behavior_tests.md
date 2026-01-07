# Nexus CLI 行为测试用例

本文档定义了 `/nexus` 命令的行为测试用例，用于验证实际运行与设计规格的一致性。

## 测试环境

- **测试目标**: `commands/nexus.md`
- **版本**: v4.0.0
- **测试日期**: 2025-12-19

---

## 测试类别

### TC-1: Spec 流程强制执行 (FORCE_SPEC_FIRST)

#### TC-1.1: 基本调用必须进入 Spec 阶段

**输入**:
```
/nexus 创建用户登录功能
```

**预期行为**:
- ✅ 进入阶段 1 (需求收集)
- ✅ 生成 `.claude/specs/[功能名称]/requirements.md`
- ✅ 使用 AskUserQuestion 询问用户确认

**验证点**:
- [ ] 没有直接开始执行任务
- [ ] 没有直接调用 PAL clink
- [ ] 先创建了 spec 目录
- [ ] 生成了 requirements.md 文件

---

#### TC-1.2: --skip-spec 标志跳过 Spec 阶段

**输入**:
```
/nexus --skip-spec 创建用户登录功能
```

**预期行为**:
- ✅ 跳过阶段 1-3 (Spec 流程)
- ✅ 直接进入阶段 4 (初始化与用户确认)
- ✅ 仍然使用 AskUserQuestion 确认执行器

**验证点**:
- [ ] 没有生成 requirements.md
- [ ] 没有生成 design.md
- [ ] 没有生成 tasks.md
- [ ] 直接进行任务分析和执行器确认

---

### TC-2: 用户确认强制执行 (FORCE_USER_CONFIRMATION)

#### TC-2.1: 阶段 1 需求确认

**场景**: 完成 requirements.md 生成后

**预期行为**:
- ✅ 使用 AskUserQuestion 工具
- ✅ 提供三个选项: "是，继续设计" / "需要修改" / "完全重写"
- ✅ 等待用户响应后才进入阶段 2

**验证点**:
- [ ] AskUserQuestion 被调用
- [ ] 问题包含 "需求" 相关内容
- [ ] 提供了明确的选项

---

#### TC-2.2: 阶段 2 设计确认

**场景**: 完成 design.md 生成后

**预期行为**:
- ✅ 使用 AskUserQuestion 工具
- ✅ 提供三个选项: "是，继续任务" / "需要修改" / "返回需求"
- ✅ 等待用户响应后才进入阶段 3

**验证点**:
- [ ] AskUserQuestion 被调用
- [ ] 问题包含 "设计" 相关内容
- [ ] 可以返回阶段 1

---

#### TC-2.3: 阶段 3 任务确认

**场景**: 完成 tasks.md 生成后

**预期行为**:
- ✅ 使用 AskUserQuestion 工具
- ✅ 提供三个选项: "是，开始执行" / "需要修改" / "返回设计"
- ✅ 等待用户响应后才进入阶段 4

**验证点**:
- [ ] AskUserQuestion 被调用
- [ ] tasks.md 使用批次格式
- [ ] 可以返回阶段 2

---

#### TC-2.4: 阶段 4 执行器确认

**场景**: 进入 Nexus 执行流程

**预期行为**:
- ✅ 展示批次和执行器分配
- ✅ 使用 AskUserQuestion 确认执行计划
- ✅ 只有用户同意后才开始批次执行

**验证点**:
- [ ] AskUserQuestion 被调用
- [ ] 显示了执行器分配 (Claude/Gemini/Codex)
- [ ] 用户可以调整或取消

---

### TC-3: 原子任务强制执行 (FORCE_ATOMIC_TASKS)

#### TC-3.1: 任务粒度验证

**场景**: tasks.md 生成

**预期行为**:
- ✅ 每个任务预估时间 ≤ 5 分钟
- ✅ 每个任务有明确的输出文件
- ✅ 每个任务可独立验证

**验证点**:
- [ ] 没有出现 ">5min" 或 "10min", "30min" 等
- [ ] 大任务被拆分为多个小任务
- [ ] 每个任务有清晰的完成标准

---

### TC-4: 批次分组强制执行 (FORCE_BATCH_GROUPING)

#### TC-4.1: 批次格式验证

**场景**: tasks.md 生成

**预期行为**:
- ✅ 任务按依赖关系分组为批次
- ✅ 每个批次有明确标题
- ✅ 批次内任务可并行执行

**验证点**:
- [ ] 出现 "批次 1:", "批次 2:" 等格式
- [ ] 每个批次有完成标准
- [ ] 串行依赖在不同批次

---

### TC-5: TodoWrite 即时更新 (FORCE_BATCH_TODOWRITE)

#### TC-5.1: 批次完成后更新

**场景**: 批次执行

**预期行为**:
- ✅ 批次开始时标记 in_progress
- ✅ 批次完成后立即标记 completed
- ✅ 不批量更新多个批次

**验证点**:
- [ ] 每个批次完成后都有 TodoWrite 调用
- [ ] 状态流转: pending → in_progress → completed
- [ ] 任何时候只有一个批次是 in_progress

---

### TC-6: 阶段编号验证

#### TC-6.1: 阶段从 1 开始

**预期行为**:
- ✅ 阶段 1: 需求收集
- ✅ 阶段 2: 设计文档
- ✅ 阶段 3: 实施计划
- ✅ 阶段 4: 初始化与用户确认
- ✅ 阶段 5: 批次执行循环
- ✅ 阶段 6: 验收测试

**验证点**:
- [ ] 没有出现 "阶段 -3", "阶段 -2", "阶段 -1"
- [ ] 阶段编号连续 (1-6)
- [ ] 输出格式使用正确的阶段编号

---

### TC-7: 执行器路由验证

#### TC-7.1: 前端任务路由到 Gemini

**输入**:
```
/nexus 创建 React 登录表单组件
```

**预期行为**:
- ✅ AI 分析识别为前端任务
- ✅ 推荐使用 Gemini CLI
- ✅ 使用 PAL clink 调用 Gemini

**验证点**:
- [ ] 执行器分配显示 "Gemini"
- [ ] clink 调用使用 `cli_name: "gemini"`

---

#### TC-7.2: 后端任务路由到 Codex

**输入**:
```
/nexus 创建用户认证 API
```

**预期行为**:
- ✅ AI 分析识别为后端任务
- ✅ 推荐使用 Codex CLI
- ✅ 使用 PAL clink 调用 Codex

**验证点**:
- [ ] 执行器分配显示 "Codex"
- [ ] clink 调用使用 `cli_name: "codex"`

---

#### TC-7.3: 混合任务正确拆分

**输入**:
```
/nexus 创建用户认证系统，包括登录表单和后端 API
```

**预期行为**:
- ✅ 任务被拆分为多个子任务
- ✅ 前端子任务 → Gemini
- ✅ 后端子任务 → Codex
- ✅ 架构分析 → Claude

**验证点**:
- [ ] 不是整体派发到单一执行器
- [ ] 各子任务使用最合适的执行器

---

### TC-8: 禁止行为验证

#### TC-8.1: 不跳过 Spec 流程

**场景**: 调用 /nexus 不带 --skip-spec

**预期行为**:
- ✅ 必须先完成 Spec 流程
- ❌ 不能直接开始执行任务

**验证点**:
- [ ] 没有直接调用 Task tool 执行任务
- [ ] 没有直接调用 PAL clink

---

#### TC-8.2: 不跳过用户确认

**场景**: 任何阶段转换

**预期行为**:
- ✅ 每个阶段结束都有用户确认
- ❌ 不能自动进入下一阶段

**验证点**:
- [ ] 每个阶段都调用了 AskUserQuestion
- [ ] 等待用户响应后才继续

---

#### TC-8.3: 不批量更新 TodoWrite

**场景**: 批次执行

**预期行为**:
- ✅ 每个批次完成后立即更新
- ❌ 不能等所有批次完成才更新

**验证点**:
- [ ] TodoWrite 调用次数 ≥ 批次数量
- [ ] 用户能看到实时进度

---

## 测试执行脚本

以下命令用于验证 nexus.md 的关键设计点：

```bash
# 验证阶段编号（应该没有负数）
grep -E "阶段 -[0-9]" commands/nexus.md && echo "❌ FAIL: 发现负数阶段" || echo "✅ PASS: 阶段编号正确"

# 验证 FORCE_SPEC_FIRST 约束存在
grep -q "FORCE_SPEC_FIRST" commands/nexus.md && echo "✅ PASS: FORCE_SPEC_FIRST 约束存在" || echo "❌ FAIL: 缺少 FORCE_SPEC_FIRST"

# 验证 FORCE_USER_CONFIRMATION 约束存在
grep -q "FORCE_USER_CONFIRMATION" commands/nexus.md && echo "✅ PASS: FORCE_USER_CONFIRMATION 约束存在" || echo "❌ FAIL: 缺少 FORCE_USER_CONFIRMATION"

# 验证 AskUserQuestion 使用
grep -c "AskUserQuestion" commands/nexus.md | xargs -I {} sh -c '[ {} -ge 4 ] && echo "✅ PASS: AskUserQuestion 调用足够 ({} 次)" || echo "❌ FAIL: AskUserQuestion 调用不足 ({} 次)"'

# 验证批次格式存在
grep -q "批次 1:" commands/nexus.md && echo "✅ PASS: 批次格式正确" || echo "❌ FAIL: 缺少批次格式"

# 验证 --skip-spec 标志文档
grep -q "\-\-skip-spec" commands/nexus.md && echo "✅ PASS: --skip-spec 标志已文档化" || echo "❌ FAIL: 缺少 --skip-spec 文档"

# 验证阶段 1-6 完整性
for i in 1 2 3 4 5 6; do
  grep -q "阶段 $i:" commands/nexus.md && echo "✅ PASS: 阶段 $i 存在" || echo "❌ FAIL: 缺少阶段 $i"
done
```

---

## 测试结果记录

| 测试用例 | 状态 | 备注 |
|---------|------|------|
| TC-1.1 | ⏳ | |
| TC-1.2 | ⏳ | |
| TC-2.1 | ⏳ | |
| TC-2.2 | ⏳ | |
| TC-2.3 | ⏳ | |
| TC-2.4 | ⏳ | |
| TC-3.1 | ⏳ | |
| TC-4.1 | ⏳ | |
| TC-5.1 | ⏳ | |
| TC-6.1 | ⏳ | |
| TC-7.1 | ⏳ | |
| TC-7.2 | ⏳ | |
| TC-7.3 | ⏳ | |
| TC-8.1 | ⏳ | |
| TC-8.2 | ⏳ | |
| TC-8.3 | ⏳ | |

**图例**: ✅ 通过 | ❌ 失败 | ⏳ 待测试

---

## 自动化测试脚本

运行以下命令执行所有静态验证测试：

```bash
cd ~/path/to/nexus-cli
bash tests/run_static_tests.sh
```
