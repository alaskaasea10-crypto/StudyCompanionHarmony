import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from agent_service import (  # noqa: E402
    AgentServiceError,
    build_messages,
    build_support_messages,
    call_emotional_support,
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
        self.assertIn("不生成要求打开这些模块的任务", messages[0]["content"])
        self.assertIn('"distinctQuestions":2', messages[1]["content"])
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
