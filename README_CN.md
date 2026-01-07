# Nexus CLI

> *智能路由，精准匹配。*

[English](README.md)

**Claude Code 智能任务路由器** - 根据任务特性自动将开发任务路由到最合适的 AI 执行器（Claude、Gemini 或 Codex）。

## 功能特性

- **智能任务路由**：AI 驱动分析，为每个任务选择最优执行器
- **多执行器支持**：通过 PAL MCP 无缝集成 Claude、Gemini CLI 和 Codex CLI
- **结构化工作流**：规格优先方法，包含需求 → 设计 → 实现阶段
- **批次执行**：原子任务分解（每个 ≤5 分钟）支持并行执行
- **实时进度**：集成 TodoWrite 实现实时进度跟踪
- **AI 代码审查**：由 PAL MCP 驱动的智能代码审查

## 环境要求

- [Claude Code](https://claude.ai/code) 已安装并配置
- [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server) 用于 Gemini/Codex CLI 集成（可选，启用多执行器路由）

## 安装

```bash
# 克隆仓库
git clone https://github.com/CoderMageFox/nexus-cli.git
cd nexus-cli

# 运行安装脚本
./install-nexus-skill.sh
```

安装脚本将：
1. 将 Nexus 注册为 Claude Code 技能到 `~/.claude/commands/nexus.md`
2. 创建默认配置文件 `.nexus-config.yaml`
3. 检查可选依赖项（PAL MCP、Gemini CLI、Codex CLI）

### PAL MCP 配置（可选）

要启用多执行器路由，请将 PAL MCP 添加到 `~/.claude.json`：

```json
{
  "mcpServers": {
    "pal": {
      "command": "npx",
      "args": ["-y", "pal-mcp-server"],
      "env": {
        "GEMINI_API_KEY": "your-gemini-api-key"
      }
    }
  }
}
```

## 使用方法

在 Claude Code 中，使用以下命令调用 Nexus：

```
/nexus <你的任务描述>
```

### 示例

```bash
# 完整工作流，包含规格生成
/nexus 创建一个带有 JWT 令牌的用户认证系统

# 简单任务跳过规格阶段
/nexus 创建一个 hello world 函数 --skip-spec

# 前端任务（路由到 Gemini）
/nexus 构建一个响应式登录表单组件

# 后端任务（路由到 Codex）
/nexus 实现用户管理的 REST API 端点
```

## 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│              阶段 0: PAL MCP 可用性检查                      │
│         可用 → 正常模式 | 不可用 → 仅 Claude 模式            │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    SPEC 流程 (阶段 1-3)                      │
│  阶段 1: 需求（EARS 格式）                                   │
│  阶段 2: 设计文档                                           │
│  阶段 3: 任务分解（批次格式）                                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                 执行流程 (阶段 4-5)                          │
│  阶段 4: TodoWrite 初始化 + 用户确认                        │
│  阶段 5: 批次执行循环                                       │
│           ├─ 按批次并行执行任务                             │
│           ├─ 每批次完成后立即更新 TodoWrite                 │
│           └─ 路由: Claude→Task, Gemini/Codex→PAL clink      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              质量门控 (阶段 6) - 可选                        │
│                     AI 代码审查                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              完成选项 (阶段 7)                               │
│         验收确认 → 文档生成                                 │
└─────────────────────────────────────────────────────────────┘
```

## 执行器选择

| 执行器 | 最适合 | 图标 |
|--------|--------|------|
| **Claude** | 架构设计、深度分析、安全审查、复杂推理 | 🧠 |
| **Gemini** | 前端 UI、算法、网络搜索、创意任务 | 💎 |
| **Codex** | 后端 API、数据库、服务端逻辑 | 🔷 |

## 配置

编辑项目根目录下的 `.nexus-config.yaml`：

```yaml
# 语言: auto, zh-CN, en-US
language: auto

# 执行器路由规则
routing:
  default_executor: claude
  rules:
    - pattern: "**/components/**"
      executor: gemini
      description: "React/Vue 组件"
    - pattern: "**/api/**"
      executor: codex
      description: "API 端点"

# 执行设置
execution:
  max_parallel_tasks: 5
  task_timeout_minutes: 10
  batch_timeout_minutes: 30

# 质量门控（AI 驱动）
quality_gates:
  enabled: true
  gates:
    review:
      enabled: true
      focus:
        - security
        - performance
        - quality
```

## 强制性约束

| 约束 | 要求 |
|------|------|
| `FORCE_PAL_CHECK` | 路由到 Gemini/Codex 前必须检查 PAL MCP 可用性 |
| `FORCE_SPEC_FIRST` | 执行前必须完成 Spec 流程（除非使用 `--skip-spec`） |
| `FORCE_ATOMIC_TASKS` | 每个任务必须 ≤5 分钟 |
| `FORCE_BATCH_GROUPING` | 任务必须按依赖关系分组 |
| `FORCE_BATCH_TODOWRITE` | 每批次完成后必须立即更新 TodoWrite |
| `FORCE_USER_CONFIRMATION` | 执行前必须获取用户确认 |

## 脚本

| 脚本 | 描述 |
|------|------|
| `./install-nexus-skill.sh` | 安装 Nexus CLI |
| `./uninstall-nexus.sh` | 卸载 Nexus CLI |
| `./update-nexus.sh` | 更新到最新版本 |

### 安装选项

```bash
./install-nexus-skill.sh [选项]

选项:
  --quick         跳过依赖检查
  --check-deps    仅检查依赖，不安装
  --help          显示帮助信息
```

## 项目结构

```
nexus-cli/
├── commands/
│   └── nexus.md           # 主技能定义
├── lib/                   # 库模块
├── locales/               # 国际化翻译 (en-US, zh-CN)
├── templates/             # 文档模板
├── tests/                 # 测试文件
├── install-nexus-skill.sh # 安装脚本
├── uninstall-nexus.sh     # 卸载脚本
├── update-nexus.sh        # 更新脚本
├── .nexus-config.yaml     # 配置模板
└── VERSION                # 版本文件
```

## 许可证

MIT License

## 贡献

欢迎贡献！请随时提交 Pull Request。

## 相关资源

- [Claude Code](https://claude.ai/code) - AI 驱动的编程助手
- [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server) - 多模型编排
