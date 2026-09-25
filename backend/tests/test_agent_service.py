import sys
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from agent_service import (  # noqa: E402
    AgentServiceError,
    AgentConfig,
    build_messages,
    build_support_messages,
    call_emotional_support,
    call_openpangu,
    load_config,
    parse_json_object,
    validate_plan,
    validate_request,
    validate_support_request,
)


class AgentServiceTests(unittest.TestCase):
    def test_emotional_support_is_short_private_and_not_diagnostic(self) -> None:
        data = validate_support_request({
            "message": "最近考试压力很大",
            "history": [{"role": "assistant", "text": "我在听", "id": "ignored"}],
        })
        prompt = build_support_messages(data)[0]["content"]
        self.assertIn("不做心理疾病诊断", prompt)
        self.assertIn("不得被描述为已写入学习画像", prompt)
        self.assertEqual("assistant", build_support_messages(data)[1]["role"])

    def test_crisis_support_does_not_wait_for_model(self) -> None:
        data = validate_support_request({"message": "我不想活了", "history": []})
        result = call_emotional_support(data, load_config())
        self.assertTrue(result["crisis"])
        self.assertIn("不要独处", result["reply"])
        self.assertIn("120", result["reply"])
    def test_concise_prompt_keeps_essential_evidence(self) -> None:
        prompt = build_messages({})[0]['content']
        self.assertIn('summary 只写一句行动结论', prompt)
        self.assertIn('recommendationReasons 最多 2 条', prompt)
        self.assertIn('不为凑字数改变含义', prompt)

    def test_self_report_prompt_removes_bank_flow_without_inventing_score(self) -> None:
        messages = build_messages({
            "requestText": "复习矩阵乘法", "profile": {},
            "context": {"bankEvidence": [{"knowledgePoint": "矩阵乘法 · 运算顺序",
                "status": "建议复习", "distinctQuestions": 2, "latestCorrect": 1}]},
        })
        self.assertIn("不把自述当作客观诊断", messages[0]["content"])
        self.assertIn("不要根据工具以外的信息猜测学习数据", messages[0]["content"])
        self.assertNotIn('"distinctQuestions":2', messages[1]["content"])
        self.assertNotIn("bankEvidence", messages[1]["content"])
        self.assertNotIn('"score"', messages[1]["content"])

    def test_request_requires_text(self) -> None:
        with self.assertRaises(AgentServiceError):
            validate_request({"requestText": "", "profile": {}, "context": {}})

    def test_request_clamps_available_minutes(self) -> None:
        request = validate_request(
            {
                "requestText": "今天复习矩阵",
                "profile": {"dailyMinutes": 60},
                "context": {"availableMinutesToday": 120},
            }
        )
        self.assertEqual(request["context"]["availableMinutesToday"], 120)

    def test_unknown_availability_is_not_inferred_from_profile(self) -> None:
        request = validate_request({
            "requestText": "帮我安排学习", "profile": {"dailyMinutes": 60}, "context": {}
        })
        self.assertNotIn("availableMinutesToday", request["context"])

    def test_multi_subject_prompt_uses_real_task_ids(self) -> None:
        prompt = build_messages({})[0]["content"]
        self.assertIn("多个科目", prompt)
        self.assertIn("taskId", prompt)
        self.assertIn("detectedSubject 仅表示当前请求", prompt)
        self.assertIn("不要为了多学科而强制轮换", prompt)

    def test_native_tool_loop_uses_real_tools_then_validates_plan(self) -> None:
        task = {"id": "real-task-1", "title": "整理矩阵笔记", "subject": "线性代数",
                "minutes": 25, "completed": False, "outcome": "pending"}
        data = validate_request({
            "requestText": "帮我安排今天的学习", "profile": {"dailyMinutes": 60},
            "context": {"date": "2026-09-25", "availableMinutesToday": 30,
                        "scheduleReady": True, "scheduleItems": [], "academicGoals": [],
                        "recentFocusRecords": [], "unfinishedTasks": [task],
                        "eligibleTaskIds": ["real-task-1"]},
        })
        responses = [
            {"choices": [{"message": {"role": "assistant", "content": "", "tool_calls": [
                {"id": "call_tasks", "type": "function",
                 "function": {"name": "getCurrentTasks", "arguments": "{}"}},
                {"id": "call_schedule", "type": "function",
                 "function": {"name": "getTodaySchedule", "arguments": "{}"}},
            ]}}], "usage": {"prompt_tokens": 10, "completion_tokens": 4, "total_tokens": 14}},
            {"choices": [{"message": {"role": "assistant", "content": '{"summary":"先整理矩阵笔记",'
                '"detectedSubject":"线性代数","recommendationReasons":["已有待办"],"tasks":['
                '{"taskId":"real-task-1","title":"整理矩阵笔记","subject":"线性代数",'
                '"type":"review","minutes":25,"priority":1,"reason":"已有真实任务"}]}'}}],
             "usage": {"prompt_tokens": 20, "completion_tokens": 8, "total_tokens": 28}},
        ]
        sent_payloads = []

        def transport(payload, _config, _timeout):
            sent_payloads.append(payload)
            return responses.pop(0)

        output = StringIO()
        with redirect_stdout(output):
            result = call_openpangu(data, AgentConfig("top-secret", "https://example.invalid", "test-model"),
                                    transport=transport)
        self.assertEqual("native-tool-loop", result["agentMode"])
        self.assertEqual(["getCurrentTasks", "getTodaySchedule"], result["toolCalls"])
        self.assertEqual(2, result["rounds"])
        self.assertEqual("real-task-1", result["tasks"][0]["taskId"])
        self.assertEqual(42, result["usage"]["totalTokens"])
        self.assertEqual("auto", sent_payloads[0]["tool_choice"])
        self.assertNotIn("unfinishedTasks", sent_payloads[0]["messages"][1]["content"])
        self.assertEqual("tool", sent_payloads[1]["messages"][-1]["role"])
        trace = output.getvalue()
        self.assertIn('"event":"tool_call"', trace)
        self.assertIn('"event":"plan_validated"', trace)
        self.assertNotIn("top-secret", trace)
        self.assertNotIn("top-secret", str(result))
        self.assertNotIn("整理矩阵笔记", trace)

    def test_tool_loop_stops_after_maximum_rounds(self) -> None:
        data = validate_request({"requestText": "安排学习", "profile": {}, "context": {
            "date": "2026-09-25", "unfinishedTasks": [], "eligibleTaskIds": []}})
        calls = 0

        def transport(_payload, _config, _timeout):
            nonlocal calls
            calls += 1
            return {"choices": [{"message": {"role": "assistant", "content": "", "tool_calls": [{
                "id": f"call_{calls}", "type": "function",
                "function": {"name": "getCurrentTasks", "arguments": "{}"}}]}}]}

        with redirect_stdout(StringIO()), self.assertRaisesRegex(AgentServiceError, "超过安全轮数"):
            call_openpangu(data, AgentConfig("secret", "https://example.invalid", "test-model"),
                           transport=transport)
        self.assertEqual(5, calls)

    def test_unknown_tool_call_fails_closed(self) -> None:
        data = validate_request({"requestText": "安排学习", "profile": {}, "context": {
            "date": "2026-09-25", "unfinishedTasks": []}})

        def transport(_payload, _config, _timeout):
            return {"choices": [{"message": {"role": "assistant", "content": "", "tool_calls": [{
                "id": "call_bad", "type": "function",
                "function": {"name": "completeTask", "arguments": "{}"}}]}}]}

        with redirect_stdout(StringIO()), self.assertRaisesRegex(AgentServiceError, "不允许调用工具"):
            call_openpangu(data, AgentConfig("secret", "https://example.invalid", "test-model"),
                           transport=transport)

    def test_strict_plan_rejects_invented_and_completed_ids(self) -> None:
        real = [{"id": "math-1", "title": "复习高数", "subject": "高等数学",
                 "minutes": 25, "completed": False},
                {"id": "english-1", "title": "完成英语作业", "subject": "大学英语",
                 "minutes": 20, "completed": False},
                {"id": "linear-1", "title": "整理线代笔记", "subject": "线性代数",
                 "minutes": 15, "completed": False}]
        context = {"date": "2026-09-20", "eligibleTaskIds": [item["id"] for item in real]}
        stages = [{"taskId": item["id"], "title": item["title"],
                   "subject": item["subject"], "minutes": item["minutes"],
                   "priority": index + 1} for index, item in enumerate(real)]
        valid = validate_plan({"tasks": stages}, 60, real, context)
        self.assertEqual([item["taskId"] for item in valid["tasks"]],
                         ["math-1", "english-1", "linear-1"])
        self.assertEqual(valid["totalMinutes"], 60)
        with self.assertRaises(AgentServiceError):
            validate_plan({"tasks": [{**stages[0], "taskId": "invented"}]}, 60, real, context)
        with self.assertRaises(AgentServiceError):
            validate_plan({"tasks": stages}, None, real, context)
        skipped_context = {**context, "todayStudyOverride": {
            "date": "2026-09-20", "skippedTaskIds": ["english-1"]}}
        with self.assertRaises(AgentServiceError):
            validate_plan({"tasks": [stages[1]]}, 60, real, skipped_context)
        real[0]["completed"] = True
        with self.assertRaises(AgentServiceError):
            validate_plan({"tasks": stages}, 60, real, context)

    def test_planning_prompt_never_replaces_tasks_with_rest(self) -> None:
        prompt = build_messages({})[0]["content"]
        self.assertIn("不得只回复“休息”“调整计划”", prompt)
        self.assertIn("清晰产出", prompt)

    def test_json_parser_accepts_markdown_fence(self) -> None:
        parsed = parse_json_object('```json\n{"summary":"今天复习","tasks":[]}\n```')
        self.assertEqual(parsed["summary"], "今天复习")

    def test_plan_is_clamped_to_daily_minutes(self) -> None:
        plan = validate_plan(
            {
                "summary": "先复习再小测",
                "detectedSubject": "线性代数",
                "recommendationReasons": ["考试临近"],
                "tasks": [
                    {
                        "title": "复习矩阵乘法",
                        "subject": "线性代数",
                        "type": "review",
                        "minutes": 45,
                        "priority": 1,
                        "reason": "薄弱点",
                    },
                    {
                        "title": "完成矩阵小测",
                        "subject": "线性代数",
                        "type": "quiz",
                        "minutes": 30,
                        "priority": 2,
                        "reason": "即时反馈",
                    },
                ],
            },
            60,
        )
        self.assertEqual(plan["totalMinutes"], 60)
        self.assertEqual(plan["tasks"][1]["minutes"], 15)

    def test_invalid_task_type_falls_back(self) -> None:
        plan = validate_plan(
            {
                "tasks": [
                    {
                        "title": "梳理重点",
                        "subject": "操作系统",
                        "type": "unknown",
                        "minutes": 20,
                    }
                ]
            },
            30,
        )
        self.assertEqual(plan["tasks"][0]["type"], "practice")


if __name__ == "__main__":
    unittest.main()
