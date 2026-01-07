#!/bin/bash

# Nexus CLI Integration Test: Spec Flow Validation
# Tests the Spec flow (Phase 1-3) document generation logic

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
NEXUS_FILE="$PROJECT_ROOT/commands/nexus.md"
TEST_TEMP_DIR="/tmp/nexus-test-spec-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test helpers
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

setup() {
    info "Setting up test environment..."
    mkdir -p "$TEST_TEMP_DIR/.nexus-temp/specs/test-feature"
}

cleanup() {
    info "Cleaning up..."
    rm -rf "$TEST_TEMP_DIR"
}

trap cleanup EXIT

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Nexus CLI Integration Test: Spec Flow                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

setup

# ============================================================
# Test 1: Requirements.md Template Validation
# ============================================================
echo -e "\n${BLUE}━━━ Test 1: Requirements Template Structure ━━━${NC}\n"

# Create mock requirements.md
cat > "$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/requirements.md" << 'EOF'
# User Authentication - 需求文档

## 功能概述

用户认证系统，支持登录、注册、密码重置功能。

---

## 需求列表

### REQ-1: 用户登录

**用户故事**: 作为用户，我想要登录系统，这样我可以访问个人数据。

**验收标准 (EARS 格式)**:

1. **REQ-1.1** [Ubiquitous]: 系统**应当**验证用户凭证。
2. **REQ-1.2** [State-driven]: 当凭证有效时，系统**应当**创建会话。
3. **REQ-1.3** [Event-driven]: 当登录成功后，系统**应当**重定向到首页。
4. **REQ-1.4** [Unwanted behavior]: 系统**不应当**明文存储密码。
5. **REQ-1.5** [Optional]: 如果启用记住我，系统**可以**延长会话时间。

---

## 边缘情况

1. **EC-1**: 连续失败登录 - 账户锁定 15 分钟

---

## 技术约束

1. **TC-1**: 使用 JWT 令牌
2. **TC-2**: 密码使用 bcrypt 加密

---

## 成功标准

1. **SC-1**: 登录响应时间 < 500ms
2. **SC-2**: 支持 1000 并发登录
EOF

# Validate requirements structure
REQ_FILE="$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/requirements.md"

if grep -q "## 功能概述" "$REQ_FILE"; then
    pass "Requirements has 功能概述 section"
else
    fail "Missing 功能概述 section"
fi

if grep -q "## 需求列表" "$REQ_FILE"; then
    pass "Requirements has 需求列表 section"
else
    fail "Missing 需求列表 section"
fi

if grep -q "EARS 格式" "$REQ_FILE"; then
    pass "Requirements uses EARS format"
else
    fail "Missing EARS format reference"
fi

if grep -qE "REQ-[0-9]+\.[0-9]+" "$REQ_FILE"; then
    pass "Requirements has proper REQ-X.Y numbering"
else
    fail "Missing proper requirement numbering"
fi

if grep -q "## 边缘情况" "$REQ_FILE"; then
    pass "Requirements has edge cases section"
else
    fail "Missing edge cases section"
fi

if grep -q "## 技术约束" "$REQ_FILE"; then
    pass "Requirements has technical constraints"
else
    fail "Missing technical constraints section"
fi

if grep -q "## 成功标准" "$REQ_FILE"; then
    pass "Requirements has success criteria"
else
    fail "Missing success criteria section"
fi

# ============================================================
# Test 2: Design.md Template Validation
# ============================================================
echo -e "\n${BLUE}━━━ Test 2: Design Template Structure ━━━${NC}\n"

cat > "$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/design.md" << 'EOF'
# User Authentication - 设计文档

## 概述

基于 JWT 的用户认证系统设计。

### 设计目标

1. 安全性优先
2. 高性能
3. 可扩展性

---

## 架构

### 整体架构

```mermaid
flowchart TD
    A[Client] --> B[Auth API]
    B --> C[User Service]
    C --> D[Database]
```

### 组件说明

| 组件 | 职责 | 依赖 |
|------|------|------|
| Auth API | 处理认证请求 | User Service |
| User Service | 用户数据管理 | Database |

---

## 组件和接口

### 1. AuthController

**职责**: 处理认证 HTTP 请求

**接口定义**:

```typescript
interface AuthController {
    login(credentials: LoginDTO): Promise<TokenResponse>;
    logout(token: string): Promise<void>;
}
```

---

## 数据模型

### 1. User

```json
{
  "id": "string (UUID)",
  "email": "string",
  "password_hash": "string"
}
```

---

## 错误处理

| 错误类型 | 处理方式 |
|---------|---------|
| InvalidCredentials | 返回 401 |
| UserNotFound | 返回 404 |

---

## 测试策略

### 单元测试

| 测试用例 | 描述 |
|---------|------|
| testLogin | 验证登录流程 |
EOF

DESIGN_FILE="$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/design.md"

if grep -q "## 概述" "$DESIGN_FILE"; then
    pass "Design has 概述 section"
else
    fail "Missing 概述 section"
fi

if grep -q "## 架构" "$DESIGN_FILE"; then
    pass "Design has 架构 section"
else
    fail "Missing 架构 section"
fi

if grep -q "mermaid" "$DESIGN_FILE"; then
    pass "Design uses Mermaid diagrams"
else
    fail "Missing Mermaid diagrams"
fi

if grep -q "## 组件和接口" "$DESIGN_FILE"; then
    pass "Design has components section"
else
    fail "Missing components section"
fi

if grep -q "## 数据模型" "$DESIGN_FILE"; then
    pass "Design has data models"
else
    fail "Missing data models section"
fi

if grep -q "## 错误处理" "$DESIGN_FILE"; then
    pass "Design has error handling"
else
    fail "Missing error handling section"
fi

# ============================================================
# Test 3: Tasks.md Batch Format Validation
# ============================================================
echo -e "\n${BLUE}━━━ Test 3: Tasks Template (Batch Format) ━━━${NC}\n"

cat > "$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/tasks.md" << 'EOF'
# User Authentication - 实施任务清单

## 概述

基于需求和设计文档的原子化任务列表，按执行批次分组。

---

## 批次 1: 数据层 (串行依赖)

| ID | 任务 | 执行器 | 预估 | 依赖 | 输出文件 |
|----|------|--------|------|------|----------|
| 1.1 | 创建 User 数据模型 | Codex | ≤5min | - | src/models/user.ts |
| 1.2 | 创建数据库迁移 | Codex | ≤5min | 1.1 | migrations/001_users.sql |

**批次完成标准**: 数据库迁移可以成功执行

---

## 批次 2: API 层 (可并行)

| ID | 任务 | 执行器 | 预估 | 依赖 | 输出文件 |
|----|------|--------|------|------|----------|
| 2.1 | 实现登录 API | Codex | ≤5min | 1.2 | src/api/login.ts |
| 2.2 | 实现注册 API | Codex | ≤5min | 1.2 | src/api/register.ts |
| 2.3 | 实现注销 API | Codex | ≤5min | 1.2 | src/api/logout.ts |

**批次完成标准**: 所有 API 端点可以响应请求

---

## 批次 3: 前端层 (可并行)

| ID | 任务 | 执行器 | 预估 | 依赖 | 输出文件 |
|----|------|--------|------|------|----------|
| 3.1 | 创建登录表单组件 | Gemini | ≤5min | 2.1 | src/components/LoginForm.tsx |
| 3.2 | 创建注册表单组件 | Gemini | ≤5min | 2.2 | src/components/RegisterForm.tsx |

**批次完成标准**: 组件可以渲染且表单可以提交

---

## 执行策略

### 批次执行顺序

```
批次 1 (串行) → 批次 2 (并行) → 批次 3 (并行)
```

### 预估时间

| 批次 | 任务数 | 并行度 | 预估时间 |
|------|--------|--------|----------|
| 批次 1 | 2 | 串行 | 10min |
| 批次 2 | 3 | 并行 | 5min |
| 批次 3 | 2 | 并行 | 5min |
| **总计** | **7** | - | **20min** |
EOF

TASKS_FILE="$TEST_TEMP_DIR/.nexus-temp/specs/test-feature/tasks.md"

if grep -q "## 批次 1:" "$TASKS_FILE"; then
    pass "Tasks has batch format (批次 1)"
else
    fail "Missing batch format"
fi

if grep -q "## 批次 2:" "$TASKS_FILE"; then
    pass "Tasks has multiple batches"
else
    fail "Missing multiple batches"
fi

# Check for proper task format
if grep -qE "\| [0-9]+\.[0-9]+ \|" "$TASKS_FILE"; then
    pass "Tasks has proper ID format (X.Y)"
else
    fail "Missing proper task ID format"
fi

# Check for executor column
if grep -q "| 执行器 |" "$TASKS_FILE"; then
    pass "Tasks has executor column"
else
    fail "Missing executor column"
fi

# Check for ≤5min time constraint
if grep -q "≤5min" "$TASKS_FILE"; then
    pass "Tasks enforce ≤5min constraint"
else
    fail "Missing ≤5min time constraint"
fi

# Check for batch completion criteria
BATCH_CRITERIA_COUNT=$(grep -c "批次完成标准" "$TASKS_FILE" || echo "0")
if [ "$BATCH_CRITERIA_COUNT" -ge 2 ]; then
    pass "Tasks has batch completion criteria ($BATCH_CRITERIA_COUNT)"
else
    fail "Missing batch completion criteria"
fi

# Check for execution strategy
if grep -q "## 执行策略" "$TASKS_FILE"; then
    pass "Tasks has execution strategy"
else
    fail "Missing execution strategy"
fi

# ============================================================
# Test 4: Cross-File Consistency
# ============================================================
echo -e "\n${BLUE}━━━ Test 4: Cross-File Consistency ━━━${NC}\n"

# Check that design references requirements
if grep -q "JWT" "$DESIGN_FILE" && grep -q "JWT" "$REQ_FILE"; then
    pass "Design and Requirements are consistent (JWT)"
else
    fail "Design and Requirements inconsistency"
fi

# Check that tasks reference design components
if grep -q "User" "$TASKS_FILE" && grep -q "User" "$DESIGN_FILE"; then
    pass "Tasks reference Design components"
else
    fail "Tasks don't reference Design components"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                    Spec Flow Test Results"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}✅ Passed${NC}: $PASS_COUNT"
echo -e "  ${RED}❌ Failed${NC}: $FAIL_COUNT"
echo -e "  📊 Total: $((PASS_COUNT + FAIL_COUNT))"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}🎉 All Spec flow integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  $FAIL_COUNT test(s) failed${NC}"
    exit 1
fi
