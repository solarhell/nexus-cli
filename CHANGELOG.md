# Nexus CLI - Changelog

## [4.0.0] - 2025-12-19

### Breaking Changes

**架构重构**: 从 Bash 脚本执行迁移到 PAL MCP clink 集成

#### 移除的功能

- **双进度系统**: 移除 `.nexus-progress.json`，只使用 Claude Code 原生 TodoWrite
- **Bash 后台执行**: 移除所有 Bash 脚本执行器
- **旧脚本文件**:
  - `scripts/progress_manager.py`
  - `scripts/async_executor.py`
  - `scripts/call_cli.py`
  - `scripts/gemini_wrapper.sh`
  - `scripts/codex_wrapper.sh`
  - `scripts/watch_progress.sh`
  - `scripts/atomic_task_strategy.yaml`
  - `codex_delegation_policy.yaml`
  - `tests/` 目录
  - `docs/` 目录
  - `i18n/` 目录

#### 新增核心约束

| 约束 | 说明 |
|------|------|
| `FORCE_ATOMIC_TASKS` | 必须将任务拆分为原子操作（≤5分钟） |
| `FORCE_BATCH_GROUPING` | 必须按依赖关系将任务分组为执行批次 |
| `FORCE_BATCH_TODOWRITE` | 每个批次完成后必须立即更新 TodoWrite |

#### 移除的约束

| 约束 | 原因 |
|------|------|
| `FORCE_NEXUS_PROGRESS_SYNC` | 双系统已移除 |
| `FORCE_POLLING_SYNC` | PAL MCP clink 是同步执行 |
| `FORCE_BASH_FOR_EXTERNAL` | 不再使用 Bash 执行 |

---

### Added

#### 1. PAL MCP clink 集成

**执行方式变更**:
```
之前 (Bash):
gemini "task" --yolo -o text 2>&1 &
PID=$!
# 后台执行 + 轮询监控

现在 (PAL MCP):
mcp__pal__clink({
  "prompt": "task description",
  "cli_name": "gemini"
})
# 同步执行，直接返回结果
```

**优势**:
- 同步执行，无需轮询
- 原生 MCP 集成
- 支持并行调用（单条消息多个 clink）
- 自动处理错误和超时

#### 2. 原子化任务拆分

**任务粒度要求**:
- 每个任务 ≤5 分钟
- 必须独立可验证
- 必须有明确的输出文件

**tasks.md 新格式**:
```markdown
## 批次 1: 数据层
| ID | 任务 | 执行器 | 预估 | 依赖 |
|----|------|--------|------|------|
| 1.1 | 设计 User schema | Claude | 3min | - |
| 1.2 | 创建数据库迁移 | Codex | 4min | 1.1 |

## 批次 2: API 层
| ID | 任务 | 执行器 | 预估 | 依赖 |
|----|------|--------|------|------|
| 2.1 | 实现 POST /login | Codex | 5min | 1.2 |
| 2.2 | 实现 POST /register | Codex | 5min | 1.2 |
```

#### 3. 批次化执行循环

**执行流程**:
```
For each 批次:
  ├─ 并行执行批次内所有任务
  │   ├─ Claude 任务 → Task tool
  │   └─ Gemini/Codex 任务 → clink
  ├─ 等待批次完成
  └─ 立即更新 TodoWrite ✅
```

**进度反馈**:
- 批次完成后立即更新 TodoWrite
- 用户可以看到实时进度
- 不再需要轮询 .nexus-progress.json

---

### Changed

#### 1. 安装脚本简化

**install-nexus-skill.sh**:
- 只安装 `nexus.md` 到 `~/.claude/commands/`
- 检查 PAL MCP 配置
- 移除所有 scripts 复制逻辑
- 代码从 ~200 行减少到 ~115 行

#### 2. 执行流程更新

**nexus.md v4.0.0**:
```
阶段 1: Spec 规划
├─ 原子化任务拆分
├─ 按依赖分组为批次
└─ 生成 tasks.md

阶段 2: 批次执行循环
├─ 并行执行批次内任务
├─ 等待批次完成
└─ 更新 TodoWrite

阶段 3: 验收
└─ 功能测试
```

---

### Removed

#### 文件清理

**删除的脚本** (不再需要):
- `scripts/progress_manager.py` - 双系统进度管理
- `scripts/async_executor.py` - Bash 异步执行器
- `scripts/call_cli.py` - CLI 调用脚本
- `scripts/gemini_wrapper.sh` - Gemini Bash 包装器
- `scripts/codex_wrapper.sh` - Codex Bash 包装器
- `scripts/watch_progress.sh` - 进度监控脚本
- `scripts/atomic_task_strategy.yaml` - 旧原子化策略

**删除的配置**:
- `codex_delegation_policy.yaml`
- `test_codex_config.sh`
- `verify-gemini-config.sh`
- `nexus-init.sh`
- `nexus-verify.sh`
- `uninstall-nexus-skill.sh`
- `update-nexus-skill.sh`
- `verify-nexus-skill.sh`

**删除的目录**:
- `tests/` - 旧测试（针对 Bash 执行）
- `docs/` - 旧文档
- `i18n/` - 国际化（已整合到主文档）

---

### Migration Guide

#### 从 v3.x 迁移到 v4.0.0

1. **配置 PAL MCP**:
   ```json
   // ~/.claude.json
   {
     "mcpServers": {
       "pal": {
         "command": "npx",
         "args": ["-y", "@anthropic/pal-mcp-server"],
         "env": {
           "GEMINI_API_KEY": "your-key",
           "ANTHROPIC_API_KEY": "your-key"
         }
       }
     }
   }
   ```

2. **重新安装 Nexus**:
   ```bash
   ./install-nexus-skill.sh
   ```

3. **删除旧文件** (可选):
   ```bash
   rm -rf ~/.claude/skills/nexus-cli
   rm ~/.claude/NEXUS_QUICKREF.md
   ```

4. **使用新命令**:
   ```
   /sc:nexus 你的任务描述
   ```

#### 不兼容变更

- `.nexus-progress.json` 不再使用
- 所有 Bash wrapper 脚本不再使用
- 旧的 `~/.claude/skills/nexus-cli` 目录不再需要

---

## [3.1.0] - 2025-12-18

### Added

- 会话隔离机制防止任务互相污染
- `FORCE_USER_CONFIRMATION` 约束

---

## [3.0.0] - 2025-12-15

### Added

- Spec 阶段强制流程
- tasks.md 规格文件格式
- 用户确认机制

---

## [2.0.0] - 2025-12-10

### Changed

- 架构重构: Bash 后台执行 + 轮询同步
- 实现 TodoWrite 实时更新

---

## [1.x.x] - 2025-12-04 to 2025-12-08

详细历史记录请参考 git log。

---

## 版本说明

### 版本号格式

`MAJOR.MINOR.PATCH`

- **MAJOR**: 重大架构变更，不兼容的 API 修改
- **MINOR**: 新功能添加，向后兼容
- **PATCH**: Bug 修复，小改进

### 当前状态

- **v4.0.0**: PAL MCP 集成，推荐使用
- **v3.x**: 已废弃，Bash 执行架构
- **v2.x**: 已废弃
- **v1.x**: 已废弃
