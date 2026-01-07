#!/usr/bin/env python3
"""
Nexus CLI Progress Display

Enhanced progress visualization with:
- Real-time progress bars
- Task status indicators
- Executor statistics
- Time estimates
- Rich terminal output

Compatible with both TTY and non-TTY environments.
"""

import sys
import time
import shutil
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any
from enum import Enum
from datetime import datetime, timedelta
import threading


class DisplayMode(str, Enum):
    MINIMAL = "minimal"      # Basic text output
    STANDARD = "standard"    # Progress bars + status
    RICH = "rich"           # Full visual display
    JSON = "json"           # Machine-readable output


class TaskIcon(str, Enum):
    PENDING = "⏳"
    RUNNING = "🔄"
    SUCCESS = "✅"
    FAILED = "❌"
    SKIPPED = "⏭️"
    CANCELLED = "🚫"


class ExecutorIcon(str, Enum):
    CLAUDE = "🧠"
    GEMINI = "💎"
    CODEX = "🔷"
    UNKNOWN = "⚙️"


@dataclass
class TaskProgress:
    """Progress state for a single task"""
    task_id: str
    task_name: str
    executor: str
    status: str = "pending"
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    error: Optional[str] = None
    output: Optional[str] = None


@dataclass
class BatchProgress:
    """Progress state for a batch"""
    batch_id: int
    batch_name: str
    batch_type: str
    tasks: List[TaskProgress] = field(default_factory=list)
    start_time: Optional[float] = None
    end_time: Optional[float] = None


@dataclass
class ExecutionProgress:
    """Overall execution progress state"""
    feature_name: str
    batches: List[BatchProgress] = field(default_factory=list)
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    executor_stats: Dict[str, Dict] = field(default_factory=dict)


class ProgressDisplay:
    """
    Rich progress display for Nexus CLI executions

    Features:
    - Animated progress bars
    - Color-coded status indicators
    - Real-time time estimates
    - Executor performance statistics
    """

    # ANSI color codes
    COLORS = {
        "reset": "\033[0m",
        "bold": "\033[1m",
        "dim": "\033[2m",
        "red": "\033[91m",
        "green": "\033[92m",
        "yellow": "\033[93m",
        "blue": "\033[94m",
        "magenta": "\033[95m",
        "cyan": "\033[96m",
        "white": "\033[97m",
    }

    # Progress bar characters
    BAR_FILLED = "█"
    BAR_EMPTY = "░"
    BAR_PARTIAL = ["▏", "▎", "▍", "▌", "▋", "▊", "▉"]

    def __init__(
        self,
        mode: DisplayMode = DisplayMode.STANDARD,
        use_colors: bool = True,
        update_interval: float = 0.5
    ):
        self.mode = mode
        self.use_colors = use_colors and sys.stdout.isatty()
        self.update_interval = update_interval

        # Terminal dimensions
        self.term_width, self.term_height = shutil.get_terminal_size((80, 24))

        # State
        self.progress = ExecutionProgress(feature_name="")
        self._lock = threading.Lock()
        self._update_thread: Optional[threading.Thread] = None
        self._running = False
        self._last_render_lines = 0

    # ─────────────────────────────────────────────────────────────────────────
    # Color Helpers
    # ─────────────────────────────────────────────────────────────────────────

    def _c(self, text: str, color: str) -> str:
        """Apply color to text"""
        if not self.use_colors:
            return text
        return f"{self.COLORS.get(color, '')}{text}{self.COLORS['reset']}"

    def _bold(self, text: str) -> str:
        """Make text bold"""
        if not self.use_colors:
            return text
        return f"{self.COLORS['bold']}{text}{self.COLORS['reset']}"

    def _dim(self, text: str) -> str:
        """Make text dim"""
        if not self.use_colors:
            return text
        return f"{self.COLORS['dim']}{text}{self.COLORS['reset']}"

    # ─────────────────────────────────────────────────────────────────────────
    # Icon Helpers
    # ─────────────────────────────────────────────────────────────────────────

    def _task_icon(self, status: str) -> str:
        """Get icon for task status"""
        icons = {
            "pending": TaskIcon.PENDING.value,
            "in_progress": TaskIcon.RUNNING.value,
            "completed": TaskIcon.SUCCESS.value,
            "failed": TaskIcon.FAILED.value,
            "skipped": TaskIcon.SKIPPED.value,
            "cancelled": TaskIcon.CANCELLED.value,
        }
        return icons.get(status, "•")

    def _executor_icon(self, executor: str) -> str:
        """Get icon for executor"""
        executor_lower = executor.lower()
        if "claude" in executor_lower:
            return ExecutorIcon.CLAUDE.value
        elif "gemini" in executor_lower:
            return ExecutorIcon.GEMINI.value
        elif "codex" in executor_lower:
            return ExecutorIcon.CODEX.value
        return ExecutorIcon.UNKNOWN.value

    def _status_color(self, status: str) -> str:
        """Get color for status"""
        colors = {
            "pending": "dim",
            "in_progress": "cyan",
            "completed": "green",
            "failed": "red",
            "skipped": "yellow",
            "cancelled": "magenta",
        }
        return colors.get(status, "white")

    # ─────────────────────────────────────────────────────────────────────────
    # Progress Bar
    # ─────────────────────────────────────────────────────────────────────────

    def _progress_bar(
        self,
        current: int,
        total: int,
        width: int = 30,
        show_percentage: bool = True
    ) -> str:
        """Generate a progress bar string"""
        if total == 0:
            percentage = 0
        else:
            percentage = current / total

        filled_width = int(width * percentage)
        partial_idx = int((width * percentage - filled_width) * len(self.BAR_PARTIAL))

        bar = self.BAR_FILLED * filled_width
        if partial_idx > 0 and filled_width < width:
            bar += self.BAR_PARTIAL[partial_idx - 1]
            filled_width += 1
        bar += self.BAR_EMPTY * (width - filled_width)

        # Color the bar
        bar = self._c(bar[:int(width * percentage)], "green") + self._dim(bar[int(width * percentage):])

        if show_percentage:
            return f"[{bar}] {percentage * 100:5.1f}%"
        return f"[{bar}]"

    # ─────────────────────────────────────────────────────────────────────────
    # Time Formatting
    # ─────────────────────────────────────────────────────────────────────────

    def _format_duration(self, seconds: float) -> str:
        """Format duration in human-readable form"""
        if seconds < 60:
            return f"{seconds:.1f}s"
        elif seconds < 3600:
            minutes = int(seconds // 60)
            secs = int(seconds % 60)
            return f"{minutes}m {secs}s"
        else:
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            return f"{hours}h {minutes}m"

    def _estimate_remaining(self) -> Optional[str]:
        """Estimate remaining time based on completed tasks"""
        with self._lock:
            if not self.progress.start_time:
                return None

            total_tasks = sum(len(b.tasks) for b in self.progress.batches)
            completed_tasks = sum(
                1 for b in self.progress.batches for t in b.tasks
                if t.status in ["completed", "failed", "skipped"]
            )

            if completed_tasks == 0:
                return None

            elapsed = time.time() - self.progress.start_time
            avg_time_per_task = elapsed / completed_tasks
            remaining_tasks = total_tasks - completed_tasks

            if remaining_tasks <= 0:
                return None

            remaining_seconds = avg_time_per_task * remaining_tasks
            return self._format_duration(remaining_seconds)

    # ─────────────────────────────────────────────────────────────────────────
    # Rendering
    # ─────────────────────────────────────────────────────────────────────────

    def _clear_previous(self):
        """Clear previously rendered lines"""
        if self._last_render_lines > 0 and sys.stdout.isatty():
            # Move cursor up and clear lines
            sys.stdout.write(f"\033[{self._last_render_lines}A")
            for _ in range(self._last_render_lines):
                sys.stdout.write("\033[2K\n")
            sys.stdout.write(f"\033[{self._last_render_lines}A")
            sys.stdout.flush()

    def _render_header(self) -> List[str]:
        """Render the header section"""
        lines = []

        # Title bar
        title = f" {self._bold('Nexus CLI')} - {self.progress.feature_name} "
        border = "═" * (self.term_width - 2)
        lines.append(self._c(f"╔{border}╗", "cyan"))

        # Center title
        padding = (self.term_width - len(title) - 4) // 2
        lines.append(self._c("║", "cyan") + " " * padding + title + " " * (self.term_width - padding - len(title) - 4) + self._c("║", "cyan"))
        lines.append(self._c(f"╚{border}╝", "cyan"))

        return lines

    def _render_overall_progress(self) -> List[str]:
        """Render overall progress section"""
        lines = []

        with self._lock:
            total_tasks = sum(len(b.tasks) for b in self.progress.batches)
            completed = sum(
                1 for b in self.progress.batches for t in b.tasks
                if t.status == "completed"
            )
            failed = sum(
                1 for b in self.progress.batches for t in b.tasks
                if t.status == "failed"
            )
            running = sum(
                1 for b in self.progress.batches for t in b.tasks
                if t.status == "in_progress"
            )

        # Progress bar
        bar = self._progress_bar(completed + failed, total_tasks, width=40)
        lines.append(f"\n📊 Overall Progress: {bar}")

        # Statistics
        stats = f"   {self._c(f'✅ {completed}', 'green')} completed"
        stats += f"  {self._c(f'🔄 {running}', 'cyan')} running"
        stats += f"  {self._c(f'❌ {failed}', 'red')} failed"
        stats += f"  {self._dim(f'⏳ {total_tasks - completed - failed - running}')} pending"
        lines.append(stats)

        # Time estimate
        remaining = self._estimate_remaining()
        if remaining:
            lines.append(f"   ⏱️  Estimated remaining: {self._c(remaining, 'yellow')}")

        return lines

    def _render_batch_progress(self, batch: BatchProgress) -> List[str]:
        """Render progress for a single batch"""
        lines = []

        # Batch header
        completed = sum(1 for t in batch.tasks if t.status == "completed")
        failed = sum(1 for t in batch.tasks if t.status == "failed")
        total = len(batch.tasks)

        batch_icon = "📦" if batch.batch_type == "serial" else "⚡"
        status_text = f"{completed}/{total}"
        if failed > 0:
            status_text += f" ({failed} failed)"

        lines.append(f"\n{batch_icon} {self._bold(batch.batch_name)} [{status_text}]")

        # Mini progress bar
        bar = self._progress_bar(completed + failed, total, width=20, show_percentage=False)
        lines.append(f"   {bar}")

        # Task list (show running and recently completed)
        for task in batch.tasks:
            if task.status == "in_progress":
                icon = self._task_icon(task.status)
                executor_icon = self._executor_icon(task.executor)
                elapsed = ""
                if task.start_time:
                    elapsed = f" ({self._format_duration(time.time() - task.start_time)})"
                lines.append(f"   {icon} {executor_icon} {task.task_name}{self._dim(elapsed)}")
            elif task.status == "failed":
                icon = self._task_icon(task.status)
                lines.append(f"   {icon} {self._c(task.task_name, 'red')}")
                if task.error:
                    error_preview = task.error[:50] + "..." if len(task.error) > 50 else task.error
                    lines.append(f"      {self._dim(error_preview)}")

        return lines

    def _render_executor_stats(self) -> List[str]:
        """Render executor statistics"""
        lines = []

        with self._lock:
            stats = self.progress.executor_stats

        if not stats:
            return lines

        lines.append(f"\n📈 {self._bold('Executor Statistics')}")

        for executor, data in stats.items():
            icon = self._executor_icon(executor)
            success_rate = data.get("success_rate", 0) * 100
            avg_time = data.get("avg_time", 0)

            rate_color = "green" if success_rate >= 90 else "yellow" if success_rate >= 70 else "red"

            lines.append(
                f"   {icon} {executor}: "
                f"{self._c(f'{success_rate:.0f}%', rate_color)} success, "
                f"avg {self._format_duration(avg_time)}"
            )

        return lines

    def render(self) -> str:
        """Render the full progress display"""
        lines = []

        if self.mode == DisplayMode.MINIMAL:
            # Minimal output
            with self._lock:
                total = sum(len(b.tasks) for b in self.progress.batches)
                completed = sum(
                    1 for b in self.progress.batches for t in b.tasks
                    if t.status in ["completed", "failed", "skipped"]
                )
            lines.append(f"Progress: {completed}/{total} tasks")

        elif self.mode == DisplayMode.JSON:
            # JSON output
            import json
            with self._lock:
                data = {
                    "feature": self.progress.feature_name,
                    "batches": [
                        {
                            "id": b.batch_id,
                            "name": b.batch_name,
                            "tasks": [
                                {"id": t.task_id, "status": t.status}
                                for t in b.tasks
                            ]
                        }
                        for b in self.progress.batches
                    ]
                }
            lines.append(json.dumps(data))

        else:
            # Standard and Rich modes
            if self.mode == DisplayMode.RICH:
                lines.extend(self._render_header())

            lines.extend(self._render_overall_progress())

            # Show batch progress
            with self._lock:
                for batch in self.progress.batches:
                    # Only show active or recently active batches
                    has_activity = any(
                        t.status in ["in_progress", "failed"]
                        for t in batch.tasks
                    )
                    if has_activity or batch == self.progress.batches[-1]:
                        lines.extend(self._render_batch_progress(batch))

            if self.mode == DisplayMode.RICH:
                lines.extend(self._render_executor_stats())

        return "\n".join(lines)

    def update_display(self):
        """Update the terminal display"""
        if sys.stdout.isatty():
            self._clear_previous()

        output = self.render()
        print(output)

        self._last_render_lines = output.count("\n") + 1

    # ─────────────────────────────────────────────────────────────────────────
    # State Updates
    # ─────────────────────────────────────────────────────────────────────────

    def start_execution(self, feature_name: str, batches: List[Dict]):
        """Initialize progress tracking for an execution"""
        with self._lock:
            self.progress = ExecutionProgress(
                feature_name=feature_name,
                start_time=time.time()
            )

            for batch in batches:
                batch_progress = BatchProgress(
                    batch_id=batch["id"],
                    batch_name=batch["name"],
                    batch_type=batch.get("type", "serial")
                )
                for task in batch.get("tasks", []):
                    batch_progress.tasks.append(TaskProgress(
                        task_id=task["id"],
                        task_name=task["name"],
                        executor=task["executor"]
                    ))
                self.progress.batches.append(batch_progress)

        self.update_display()

    def start_batch(self, batch_id: int):
        """Mark a batch as started"""
        with self._lock:
            for batch in self.progress.batches:
                if batch.batch_id == batch_id:
                    batch.start_time = time.time()
                    break
        self.update_display()

    def start_task(self, task_id: str):
        """Mark a task as started"""
        with self._lock:
            for batch in self.progress.batches:
                for task in batch.tasks:
                    if task.task_id == task_id:
                        task.status = "in_progress"
                        task.start_time = time.time()
                        break
        self.update_display()

    def complete_task(self, task_id: str, success: bool, error: Optional[str] = None):
        """Mark a task as completed"""
        with self._lock:
            for batch in self.progress.batches:
                for task in batch.tasks:
                    if task.task_id == task_id:
                        task.status = "completed" if success else "failed"
                        task.end_time = time.time()
                        task.error = error

                        # Update executor stats
                        executor = task.executor
                        if executor not in self.progress.executor_stats:
                            self.progress.executor_stats[executor] = {
                                "total": 0,
                                "success": 0,
                                "total_time": 0
                            }

                        stats = self.progress.executor_stats[executor]
                        stats["total"] += 1
                        if success:
                            stats["success"] += 1
                        if task.start_time and task.end_time:
                            stats["total_time"] += task.end_time - task.start_time

                        stats["success_rate"] = stats["success"] / stats["total"]
                        stats["avg_time"] = stats["total_time"] / stats["total"]
                        break
        self.update_display()

    def complete_batch(self, batch_id: int):
        """Mark a batch as completed"""
        with self._lock:
            for batch in self.progress.batches:
                if batch.batch_id == batch_id:
                    batch.end_time = time.time()
                    break
        self.update_display()

    def complete_execution(self):
        """Mark the execution as completed"""
        with self._lock:
            self.progress.end_time = time.time()
        self.update_display()

    # ─────────────────────────────────────────────────────────────────────────
    # Auto-refresh (for long-running operations)
    # ─────────────────────────────────────────────────────────────────────────

    def start_auto_refresh(self):
        """Start auto-refreshing the display"""
        self._running = True

        def refresh_loop():
            while self._running:
                self.update_display()
                time.sleep(self.update_interval)

        self._update_thread = threading.Thread(target=refresh_loop, daemon=True)
        self._update_thread.start()

    def stop_auto_refresh(self):
        """Stop auto-refreshing"""
        self._running = False
        if self._update_thread:
            self._update_thread.join(timeout=1)


# ─────────────────────────────────────────────────────────────────────────────
# Standalone Progress Printer (for simpler use cases)
# ─────────────────────────────────────────────────────────────────────────────

def print_progress_line(
    message: str,
    current: int,
    total: int,
    status: str = "running"
):
    """Print a single progress line (non-interactive)"""
    icons = {
        "running": "🔄",
        "success": "✅",
        "failed": "❌",
        "pending": "⏳"
    }
    icon = icons.get(status, "•")
    percentage = (current / total * 100) if total > 0 else 0
    print(f"{icon} [{current}/{total}] {percentage:.0f}% - {message}")


def print_task_result(task_name: str, executor: str, success: bool, duration: float):
    """Print a task result line"""
    icon = "✅" if success else "❌"
    executor_icons = {"claude": "🧠", "gemini": "💎", "codex": "🔷"}
    exec_icon = executor_icons.get(executor.lower(), "⚙️")
    print(f"  {icon} {exec_icon} {task_name} ({duration:.1f}s)")


def print_batch_summary(batch_name: str, success: int, failed: int, duration: float):
    """Print a batch summary"""
    total = success + failed
    status = "✅" if failed == 0 else "⚠️" if success > 0 else "❌"
    print(f"\n{status} {batch_name}: {success}/{total} succeeded ({duration:.1f}s)")


# ─────────────────────────────────────────────────────────────────────────────
# CLI Demo
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Nexus CLI Progress Display Demo")
    parser.add_argument("--mode", choices=["minimal", "standard", "rich"], default="standard")
    parser.add_argument("--no-color", action="store_true", help="Disable colors")
    args = parser.parse_args()

    mode = DisplayMode(args.mode)
    display = ProgressDisplay(mode=mode, use_colors=not args.no_color)

    # Demo data
    demo_batches = [
        {
            "id": 1,
            "name": "Setup & Configuration",
            "type": "serial",
            "tasks": [
                {"id": "1.1", "name": "Initialize project", "executor": "claude"},
                {"id": "1.2", "name": "Configure database", "executor": "codex"},
            ]
        },
        {
            "id": 2,
            "name": "Implementation",
            "type": "parallel",
            "tasks": [
                {"id": "2.1", "name": "Build API endpoints", "executor": "codex"},
                {"id": "2.2", "name": "Create UI components", "executor": "gemini"},
                {"id": "2.3", "name": "Write tests", "executor": "claude"},
            ]
        },
        {
            "id": 3,
            "name": "Finalization",
            "type": "serial",
            "tasks": [
                {"id": "3.1", "name": "Code review", "executor": "claude"},
                {"id": "3.2", "name": "Documentation", "executor": "gemini"},
            ]
        }
    ]

    print("🎬 Starting Progress Display Demo\n")

    display.start_execution("Demo Feature", demo_batches)
    time.sleep(1)

    # Simulate execution
    for batch in demo_batches:
        display.start_batch(batch["id"])

        for task in batch["tasks"]:
            display.start_task(task["id"])
            time.sleep(0.8)  # Simulate work

            # Random success/failure
            import random
            success = random.random() > 0.2
            display.complete_task(task["id"], success,
                                 error="Simulated error" if not success else None)

        display.complete_batch(batch["id"])

    display.complete_execution()

    print("\n🎉 Demo complete!")
