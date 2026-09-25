import copy
import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from agent_tools import AgentToolError, execute_tool, tool_definitions  # noqa: E402


class AgentToolRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.context = {
            "date": "2026-09-25",
            "scheduleReady": True,
            "scheduleItems": [
                {"id": "fri-course", "weekday": 5, "startTime": "08:00", "endTime": "09:40",
                 "course": "高等数学", "location": "A101"},
                {"id": "thu-course", "weekday": 4, "startTime": "10:00", "endTime": "11:40",
                 "course": "大学英语", "location": "B202"},
            ],
            "academicGoals": [
                {"id": "goal-real", "title": "期末复习", "subject": "高等数学", "type": "exam",
                 "deadline": "2026-09-30", "estimatedMinutes": 120, "completed": False,
                 "milestones": []},
                {"id": "goal-done", "title": "旧目标", "subject": "英语", "type": "course",
                 "deadline": "2026-09-20", "estimatedMinutes": 60, "completed": True},
            ],
            "unfinishedTasks": [
                {"id": "task-real", "title": "复习导数", "subject": "高等数学", "minutes": 30,
                 "completed": False, "outcome": "pending", "goalId": "goal-real"},
                {"id": "task-skip", "title": "整理英语", "subject": "大学英语", "minutes": 20,
                 "completed": False, "outcome": "pending"},
                {"id": "task-done", "title": "已完成", "subject": "线性代数", "minutes": 15,
                 "completed": True, "outcome": "submitted"},
            ],
            "eligibleTaskIds": ["task-real", "task-skip"],
            "todayStudyOverride": {"date": "2026-09-25", "availableMinutes": 50,
                                   "skippedTaskIds": ["task-skip"]},
            "availableMinutesToday": 50,
            "recentFocusRecords": [],
        }

    def test_registry_contains_only_four_read_only_tools(self) -> None:
        names = [item["function"]["name"] for item in tool_definitions()]
        self.assertEqual(["getTodaySchedule", "getUpcomingGoals", "getCurrentTasks", "getFocusHistory"], names)

    def test_schedule_returns_only_confirmed_items_for_today(self) -> None:
        result = execute_tool("getTodaySchedule", {}, self.context)
        self.assertEqual(["fri-course"], [item["id"] for item in result["items"]])
        empty = copy.deepcopy(self.context)
        empty["scheduleReady"] = False
        self.assertEqual([], execute_tool("getTodaySchedule", {}, empty)["items"])

    def test_goals_and_tasks_preserve_real_ids_without_mutation(self) -> None:
        original = copy.deepcopy(self.context)
        goals = execute_tool("getUpcomingGoals", {}, self.context)["goals"]
        tasks = execute_tool("getCurrentTasks", {}, self.context)["tasks"]
        self.assertEqual(["goal-real"], [goal["id"] for goal in goals])
        self.assertEqual(["task-real", "task-skip"], [task["taskId"] for task in tasks])
        self.assertFalse(tasks[1]["eligibleToday"])
        self.assertTrue(tasks[1]["skippedToday"])
        self.assertEqual(original, self.context)

    def test_empty_focus_history_stays_empty(self) -> None:
        self.assertEqual([], execute_tool("getFocusHistory", {}, self.context)["records"])

    def test_unknown_or_mutating_shape_is_rejected(self) -> None:
        with self.assertRaises(AgentToolError):
            execute_tool("completeTask", {}, self.context)
        with self.assertRaises(AgentToolError):
            execute_tool("getCurrentTasks", {"taskId": "task-real"}, self.context)


if __name__ == "__main__":
    unittest.main()
