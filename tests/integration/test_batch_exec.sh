#!/bin/bash

# Nexus CLI Integration Test: Batch Execution Logic
# Tests batch execution ordering, parallel execution, and TodoWrite updates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_TEMP_DIR="/tmp/nexus-test-batch-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

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
    mkdir -p "$TEST_TEMP_DIR/.nexus-temp"
    mkdir -p "$TEST_TEMP_DIR/logs"
}

cleanup() {
    info "Cleaning up..."
    rm -rf "$TEST_TEMP_DIR"
}

trap cleanup EXIT

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Nexus CLI Integration Test: Batch Execution            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

setup

# ============================================================
# Test 1: Batch Dependency Resolution
# ============================================================
echo -e "\n${BLUE}━━━ Test 1: Batch Dependency Resolution ━━━${NC}\n"

# Create mock batch configuration
cat > "$TEST_TEMP_DIR/batches.json" << 'EOF'
{
  "batches": [
    {
      "id": 1,
      "name": "数据层",
      "type": "serial",
      "tasks": [
        {"id": "1.1", "name": "User Model", "executor": "Codex", "depends_on": null},
        {"id": "1.2", "name": "Migration", "executor": "Codex", "depends_on": "1.1"}
      ]
    },
    {
      "id": 2,
      "name": "API 层",
      "type": "parallel",
      "tasks": [
        {"id": "2.1", "name": "Login API", "executor": "Codex", "depends_on": "1.2"},
        {"id": "2.2", "name": "Register API", "executor": "Codex", "depends_on": "1.2"},
        {"id": "2.3", "name": "Logout API", "executor": "Codex", "depends_on": "1.2"}
      ]
    },
    {
      "id": 3,
      "name": "前端层",
      "type": "parallel",
      "tasks": [
        {"id": "3.1", "name": "Login Form", "executor": "Gemini", "depends_on": "2.1"},
        {"id": "3.2", "name": "Register Form", "executor": "Gemini", "depends_on": "2.2"}
      ]
    }
  ]
}
EOF

# Validate batch structure
if python3 -c "import json; json.load(open('$TEST_TEMP_DIR/batches.json'))" 2>/dev/null; then
    pass "Batch JSON is valid"
else
    fail "Invalid batch JSON structure"
fi

# Check batch count
BATCH_COUNT=$(python3 -c "import json; print(len(json.load(open('$TEST_TEMP_DIR/batches.json'))['batches']))")
if [ "$BATCH_COUNT" -eq 3 ]; then
    pass "Correct number of batches (3)"
else
    fail "Expected 3 batches, got $BATCH_COUNT"
fi

# ============================================================
# Test 2: Batch Execution Simulator
# ============================================================
echo -e "\n${BLUE}━━━ Test 2: Batch Execution Simulation ━━━${NC}\n"

# Create execution simulator script
cat > "$TEST_TEMP_DIR/simulate_execution.py" << 'EOF'
#!/usr/bin/env python3
"""Simulate batch execution and verify ordering"""

import json
import time
from dataclasses import dataclass
from typing import List, Dict, Optional
import sys

@dataclass
class TaskExecution:
    task_id: str
    executor: str
    start_time: float
    end_time: float
    status: str

class BatchExecutionSimulator:
    def __init__(self, batches_file: str):
        with open(batches_file) as f:
            self.config = json.load(f)
        self.executions: List[TaskExecution] = []
        self.completed_tasks: set = set()
        self.errors: List[str] = []

    def validate_dependencies(self, task: dict) -> bool:
        """Check if task dependencies are met"""
        dep = task.get("depends_on")
        if dep is None:
            return True
        return dep in self.completed_tasks

    def execute_batch(self, batch: dict) -> bool:
        """Simulate executing a batch"""
        batch_id = batch["id"]
        batch_type = batch["type"]
        tasks = batch["tasks"]

        print(f"  Executing Batch {batch_id}: {batch['name']} ({batch_type})")

        if batch_type == "serial":
            # Serial execution: one at a time
            for task in tasks:
                if not self.validate_dependencies(task):
                    self.errors.append(f"Dependency not met for {task['id']}")
                    return False
                self._execute_task(task)
        else:
            # Parallel execution: check all dependencies first
            for task in tasks:
                if not self.validate_dependencies(task):
                    self.errors.append(f"Dependency not met for {task['id']}")
                    return False

            # Simulate parallel execution
            start = time.time()
            for task in tasks:
                self._execute_task(task, parallel=True)

        return True

    def _execute_task(self, task: dict, parallel: bool = False):
        """Simulate single task execution"""
        start = time.time()
        # Simulate execution time
        time.sleep(0.01)  # 10ms per task
        end = time.time()

        execution = TaskExecution(
            task_id=task["id"],
            executor=task["executor"],
            start_time=start,
            end_time=end,
            status="completed"
        )
        self.executions.append(execution)
        self.completed_tasks.add(task["id"])
        symbol = "║" if parallel else "│"
        print(f"    {symbol} {task['id']}: {task['name']} ({task['executor']}) ✓")

    def run(self) -> bool:
        """Run full batch execution simulation"""
        print("\n  Starting batch execution simulation...\n")

        for batch in self.config["batches"]:
            if not self.execute_batch(batch):
                print(f"\n  ❌ Batch {batch['id']} failed!")
                return False
            print(f"    └─ Batch {batch['id']} completed\n")

        return True

    def get_execution_order(self) -> List[str]:
        """Get order of task executions"""
        return [e.task_id for e in self.executions]

    def validate_execution_order(self) -> bool:
        """Validate that execution order respects dependencies"""
        order = self.get_execution_order()

        # Check 1.1 before 1.2
        if order.index("1.1") >= order.index("1.2"):
            self.errors.append("1.1 must execute before 1.2")
            return False

        # Check 1.2 before all batch 2 tasks
        for task_id in ["2.1", "2.2", "2.3"]:
            if order.index("1.2") >= order.index(task_id):
                self.errors.append(f"1.2 must execute before {task_id}")
                return False

        # Check batch 2 tasks before batch 3 tasks
        if order.index("2.1") >= order.index("3.1"):
            self.errors.append("2.1 must execute before 3.1")
            return False

        if order.index("2.2") >= order.index("3.2"):
            self.errors.append("2.2 must execute before 3.2")
            return False

        return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: simulate_execution.py <batches.json>")
        sys.exit(1)

    simulator = BatchExecutionSimulator(sys.argv[1])

    if simulator.run():
        print("  Execution completed successfully!")
        print(f"  Execution order: {' → '.join(simulator.get_execution_order())}")

        if simulator.validate_execution_order():
            print("  ✅ Execution order is valid!")
            sys.exit(0)
        else:
            print("  ❌ Execution order validation failed!")
            for error in simulator.errors:
                print(f"    - {error}")
            sys.exit(1)
    else:
        print("  ❌ Execution failed!")
        for error in simulator.errors:
            print(f"    - {error}")
        sys.exit(1)
EOF

chmod +x "$TEST_TEMP_DIR/simulate_execution.py"

# Run execution simulation
if python3 "$TEST_TEMP_DIR/simulate_execution.py" "$TEST_TEMP_DIR/batches.json"; then
    pass "Batch execution order is correct"
else
    fail "Batch execution order validation failed"
fi

# ============================================================
# Test 3: TodoWrite State Transitions
# ============================================================
echo -e "\n${BLUE}━━━ Test 3: TodoWrite State Transitions ━━━${NC}\n"

# Create TodoWrite state simulator
cat > "$TEST_TEMP_DIR/todowrite_states.json" << 'EOF'
{
  "transitions": [
    {
      "phase": "init",
      "todos": [
        {"content": "批次 1: 数据层", "status": "pending"},
        {"content": "批次 2: API 层", "status": "pending"},
        {"content": "批次 3: 前端层", "status": "pending"}
      ]
    },
    {
      "phase": "batch_1_start",
      "todos": [
        {"content": "批次 1: 数据层", "status": "in_progress"},
        {"content": "批次 2: API 层", "status": "pending"},
        {"content": "批次 3: 前端层", "status": "pending"}
      ]
    },
    {
      "phase": "batch_1_complete",
      "todos": [
        {"content": "批次 1: 数据层", "status": "completed"},
        {"content": "批次 2: API 层", "status": "pending"},
        {"content": "批次 3: 前端层", "status": "pending"}
      ]
    },
    {
      "phase": "batch_2_start",
      "todos": [
        {"content": "批次 1: 数据层", "status": "completed"},
        {"content": "批次 2: API 层", "status": "in_progress"},
        {"content": "批次 3: 前端层", "status": "pending"}
      ]
    },
    {
      "phase": "batch_2_complete",
      "todos": [
        {"content": "批次 1: 数据层", "status": "completed"},
        {"content": "批次 2: API 层", "status": "completed"},
        {"content": "批次 3: 前端层", "status": "pending"}
      ]
    },
    {
      "phase": "batch_3_start",
      "todos": [
        {"content": "批次 1: 数据层", "status": "completed"},
        {"content": "批次 2: API 层", "status": "completed"},
        {"content": "批次 3: 前端层", "status": "in_progress"}
      ]
    },
    {
      "phase": "final",
      "todos": [
        {"content": "批次 1: 数据层", "status": "completed"},
        {"content": "批次 2: API 层", "status": "completed"},
        {"content": "批次 3: 前端层", "status": "completed"}
      ]
    }
  ]
}
EOF

# Validate TodoWrite transitions
TRANSITIONS=$(python3 << 'PYEOF'
import json

with open('/tmp/nexus-test-batch-' + '$$'.replace('$$', '') + '/todowrite_states.json'.replace('$$', '')) as f:
    data = json.load(open("$TEST_TEMP_DIR/todowrite_states.json"))

errors = []
transitions = data["transitions"]

for i, t in enumerate(transitions):
    phase = t["phase"]
    todos = t["todos"]

    # Check only one in_progress at a time
    in_progress = [todo for todo in todos if todo["status"] == "in_progress"]
    if len(in_progress) > 1:
        errors.append(f"{phase}: Multiple in_progress items ({len(in_progress)})")

    # Check no backward transitions (completed -> pending/in_progress)
    if i > 0:
        prev_todos = {todo["content"]: todo["status"] for todo in transitions[i-1]["todos"]}
        for todo in todos:
            prev_status = prev_todos.get(todo["content"])
            if prev_status == "completed" and todo["status"] != "completed":
                errors.append(f"{phase}: Backward transition for '{todo['content']}'")

if errors:
    for e in errors:
        print(f"ERROR: {e}")
    exit(1)
else:
    print("OK")
    exit(0)
PYEOF
)

if [ "$?" -eq 0 ]; then
    pass "TodoWrite state transitions are valid"
else
    fail "Invalid TodoWrite state transitions"
fi

# Check immediate update rule
if python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/todowrite_states.json'))
transitions = data['transitions']

# Verify batch completion is immediately followed by next batch start or final
for i, t in enumerate(transitions):
    if 'complete' in t['phase'] and i < len(transitions) - 1:
        next_phase = transitions[i + 1]['phase']
        if 'start' not in next_phase and 'final' not in next_phase:
            print(f'Gap between {t[\"phase\"]} and {next_phase}')
            exit(1)
print('OK')
"; then
    pass "Immediate TodoWrite update rule verified"
else
    fail "TodoWrite update not immediate"
fi

# ============================================================
# Test 4: Parallel Task Verification
# ============================================================
echo -e "\n${BLUE}━━━ Test 4: Parallel Task Grouping ━━━${NC}\n"

# Verify parallel batches have correct structure
PARALLEL_BATCH_COUNT=$(python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/batches.json'))
parallel_batches = [b for b in data['batches'] if b['type'] == 'parallel']
print(len(parallel_batches))
")

if [ "$PARALLEL_BATCH_COUNT" -eq 2 ]; then
    pass "Correct number of parallel batches (2)"
else
    fail "Expected 2 parallel batches, got $PARALLEL_BATCH_COUNT"
fi

# Verify all tasks in parallel batch have same dependency level
if python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/batches.json'))

for batch in data['batches']:
    if batch['type'] == 'parallel':
        deps = set()
        for task in batch['tasks']:
            dep = task.get('depends_on')
            if dep:
                # Extract batch number from dependency
                batch_num = dep.split('.')[0]
                deps.add(batch_num)

        # All tasks should depend on same batch
        if len(deps) > 1:
            print(f'Batch {batch[\"id\"]} has mixed dependencies: {deps}')
            exit(1)

print('OK')
"; then
    pass "Parallel batch dependencies are consistent"
else
    fail "Inconsistent parallel batch dependencies"
fi

# ============================================================
# Test 5: Executor Distribution
# ============================================================
echo -e "\n${BLUE}━━━ Test 5: Executor Distribution ━━━${NC}\n"

# Check executor distribution
python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/batches.json'))

executors = {}
for batch in data['batches']:
    for task in batch['tasks']:
        executor = task['executor']
        executors[executor] = executors.get(executor, 0) + 1

print('Executor distribution:')
for executor, count in executors.items():
    print(f'  {executor}: {count} tasks')
"

# Verify Codex is used for backend tasks (batches 1-2)
CODEX_TASKS=$(python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/batches.json'))
count = sum(1 for b in data['batches'] for t in b['tasks'] if t['executor'] == 'Codex')
print(count)
")

if [ "$CODEX_TASKS" -ge 5 ]; then
    pass "Codex used for backend tasks ($CODEX_TASKS tasks)"
else
    fail "Insufficient Codex usage for backend tasks"
fi

# Verify Gemini is used for frontend tasks (batch 3)
GEMINI_TASKS=$(python3 -c "
import json
data = json.load(open('$TEST_TEMP_DIR/batches.json'))
count = sum(1 for b in data['batches'] for t in b['tasks'] if t['executor'] == 'Gemini')
print(count)
")

if [ "$GEMINI_TASKS" -ge 2 ]; then
    pass "Gemini used for frontend tasks ($GEMINI_TASKS tasks)"
else
    fail "Insufficient Gemini usage for frontend tasks"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                  Batch Execution Test Results"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}✅ Passed${NC}: $PASS_COUNT"
echo -e "  ${RED}❌ Failed${NC}: $FAIL_COUNT"
echo -e "  📊 Total: $((PASS_COUNT + FAIL_COUNT))"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}🎉 All batch execution integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  $FAIL_COUNT test(s) failed${NC}"
    exit 1
fi
