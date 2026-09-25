"""Read-only tools exposed to the study-planning agent.

The registry only queries the trusted context attached to the current client
request.  It is not a server-side user database and never mutates study data.
"""

from __future__ import annotations

from datetime import date
from typing import Any, Callable


class AgentToolError(RuntimeError):
    """Raised when the model requests an unknown or malformed tool call."""


ToolHandler = Callable[[dict[str, Any]], dict[str, Any]]


def _today_schedule(context: dict[str, Any]) -> dict[str, Any]:
    if context.get("scheduleReady") is not True:
        return {"date": str(context.get("date") or ""), "items": []}
    try:
        weekday = date.fromisoformat(str(context.get("date") or "")).isoweekday()
    except ValueError:
        weekday = 0
    items: list[dict[str, Any]] = []
    for item in context.get("scheduleItems") or []:
        if not isinstance(item, dict) or item.get("weekday") != weekday:
            continue
        items.append({
            "id": str(item.get("id") or ""),
            "weekday": item.get("weekday"),
            "startTime": str(item.get("startTime") or ""),
            "endTime": str(item.get("endTime") or ""),
            "course": str(item.get("course") or ""),
            "location": str(item.get("location") or ""),
        })
    return {"date": str(context.get("date") or ""), "items": items}


def _upcoming_goals(context: dict[str, Any]) -> dict[str, Any]:
    goals: list[dict[str, Any]] = []
    for goal in context.get("academicGoals") or []:
        if not isinstance(goal, dict) or goal.get("completed") is True:
            continue
        milestones: list[dict[str, Any]] = []
        for milestone in goal.get("milestones") or []:
            if not isinstance(milestone, dict) or milestone.get("completed") is True:
                continue
            milestones.append({
                "id": str(milestone.get("id") or ""),
                "title": str(milestone.get("title") or ""),
                "description": str(milestone.get("description") or ""),
                "dueDate": str(milestone.get("dueDate") or ""),
                "minutes": milestone.get("minutes"),
            })
        goals.append({
            "id": str(goal.get("id") or ""),
            "title": str(goal.get("title") or ""),
            "type": str(goal.get("type") or ""),
            "subject": str(goal.get("subject") or ""),
            "deadline": str(goal.get("deadline") or ""),
            "estimatedMinutes": goal.get("estimatedMinutes"),
            "milestones": milestones,
        })
    return {"goals": goals}


def _current_tasks(context: dict[str, Any]) -> dict[str, Any]:
    override = context.get("todayStudyOverride")
    if not isinstance(override, dict) or override.get("date") != context.get("date"):
        override = {}
    skipped = {str(task_id) for task_id in override.get("skippedTaskIds") or []}
    eligible_values = context.get("eligibleTaskIds")
    eligible = {str(task_id) for task_id in eligible_values or []}
    has_eligible_filter = isinstance(eligible_values, list)
    protected_id = str(context.get("protectedTaskId") or "")
    tasks: list[dict[str, Any]] = []
    for task in context.get("unfinishedTasks") or []:
        if not isinstance(task, dict) or task.get("completed") is True:
            continue
        task_id = str(task.get("id") or "")
        skipped_today = task_id in skipped and task_id != protected_id
        eligible_today = (not has_eligible_filter or task_id in eligible or task_id == protected_id) and not skipped_today
        tasks.append({
            "taskId": task_id,
            "title": str(task.get("title") or ""),
            "subject": str(task.get("subject") or ""),
            "minutes": task.get("minutes"),
            "outcome": str(task.get("outcome") or "pending"),
            "goalId": str(task.get("goalId") or ""),
            "source": str(task.get("source") or ""),
            "eligibleToday": eligible_today,
            "skippedToday": skipped_today,
            "protected": task_id == protected_id,
        })
    constraints: dict[str, Any] = {
        "date": str(context.get("date") or ""),
        "protectedTaskId": protected_id,
        "protectedStage": str(context.get("protectedStage") or ""),
        "preferredTaskId": str(override.get("preferredTaskId") or ""),
        "preferredSubject": str(override.get("preferredSubject") or ""),
    }
    if context.get("availableMinutesToday") is not None:
        constraints["availableMinutesToday"] = context["availableMinutesToday"]
    return {"tasks": tasks, "constraints": constraints}


def _focus_history(context: dict[str, Any]) -> dict[str, Any]:
    records: list[dict[str, Any]] = []
    for record in context.get("recentFocusRecords") or []:
        if not isinstance(record, dict):
            continue
        records.append({
            "id": str(record.get("id") or ""),
            "taskId": str(record.get("taskId") or ""),
            "taskTitle": str(record.get("taskTitle") or ""),
            "subject": str(record.get("subject") or ""),
            "plannedMinutes": record.get("plannedMinutes"),
            "elapsedSeconds": record.get("elapsedSeconds"),
            "completedAt": record.get("completedAt"),
            "dayKey": str(record.get("dayKey") or ""),
            "completed": record.get("completed") is True,
        })
    return {"records": records}


_HANDLERS: dict[str, ToolHandler] = {
    "getTodaySchedule": _today_schedule,
    "getUpcomingGoals": _upcoming_goals,
    "getCurrentTasks": _current_tasks,
    "getFocusHistory": _focus_history,
}


def tool_definitions() -> list[dict[str, Any]]:
    descriptions = {
        "getTodaySchedule": "读取本次请求中已确认的今天课表；没有已确认课表时返回空列表。",
        "getUpcomingGoals": "读取本次请求中尚未完成的长期学习目标、截止日期和阶段目标。",
        "getCurrentTasks": "读取本次请求中真实未完成任务及今天的可执行、跳过和状态保护信息。",
        "getFocusHistory": "读取本次请求中已有的最近专注记录；没有记录时返回空列表。",
    }
    return [{
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {"type": "object", "properties": {}, "additionalProperties": False},
        },
    } for name, description in descriptions.items()]


def execute_tool(name: str, arguments: dict[str, Any], context: dict[str, Any]) -> dict[str, Any]:
    handler = _HANDLERS.get(name)
    if handler is None:
        raise AgentToolError(f"不允许调用工具：{name}")
    if not isinstance(arguments, dict) or arguments:
        raise AgentToolError(f"工具 {name} 不接受参数")
    if not isinstance(context, dict):
        raise AgentToolError("工具上下文无效")
    return handler(context)


def tool_result_count(result: dict[str, Any]) -> int:
    for key in ("tasks", "items", "goals", "records"):
        value = result.get(key)
        if isinstance(value, list):
            return len(value)
    return 0
