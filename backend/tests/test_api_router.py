import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from api_router import handle_api  # noqa: E402
from agent_service import AgentServiceError  # noqa: E402
from functiongraph.index import handler  # noqa: E402


class ApiRouterTests(unittest.TestCase):
    def test_health_describes_cloud_capabilities(self) -> None:
        result = handle_api("GET", "/health", runtime_name="test-runtime")
        self.assertEqual(200, result.status)
        self.assertEqual("test-runtime", result.payload["runtime"])
        self.assertFalse(result.payload["capabilities"]["scheduleImageOcr"])
        self.assertTrue(result.payload["capabilities"]["scheduleLineParser"])

    def test_invalid_json_is_rejected(self) -> None:
        result = handle_api("POST", "/api/agent/today-plan", "not-json")
        self.assertEqual(400, result.status)
        self.assertEqual("请求不是有效 JSON", result.payload["error"])

    def test_schedule_lines_use_shared_parser(self) -> None:
        result = handle_api(
            "POST",
            "/api/schedule/parse",
            json.dumps({"lines": [{"text": "周一 08:00-09:50 高等数学 @ A203"}]}),
        )
        self.assertEqual(200, result.status)
        self.assertEqual("高等数学", result.payload["scheduleItems"][0]["course"])

    @patch("api_router.call_openpangu")
    def test_agent_route_uses_shared_service(self, mocked_call) -> None:
        mocked_call.return_value = {
            "summary": "今天复习矩阵",
            "detectedSubject": "线性代数",
            "recommendationReasons": ["考试临近"],
            "tasks": [],
            "totalMinutes": 0,
            "source": "openpangu",
            "model": "openpangu-2.0-flash",
            "usage": {"promptTokens": 1, "completionTokens": 1, "totalTokens": 2},
        }
        request = {
            "requestText": "今天复习矩阵",
            "profile": {"dailyMinutes": 30},
            "context": {"availableMinutesToday": 30},
        }
        result = handle_api("POST", "/api/agent/today-plan", json.dumps(request))
        self.assertEqual(200, result.status)
        self.assertTrue(result.payload["ok"])
        mocked_call.assert_called_once()

    @patch("api_router.call_openpangu")
    def test_agent_route_returns_safe_service_error(self, mocked_call) -> None:
        mocked_call.side_effect = AgentServiceError("暂时无法连接 openPangu 服务")
        result = handle_api("POST", "/api/agent/today-plan", json.dumps({
            "requestText": "安排今天学习",
            "profile": {"dailyMinutes": 30},
            "context": {"availableMinutesToday": 30},
        }))
        self.assertEqual(503, result.status)
        self.assertEqual({"ok": False, "error": "暂时无法连接 openPangu 服务"}, result.payload)

    @patch("api_router.call_emotional_support")
    def test_emotional_support_has_separate_route(self, mocked_call) -> None:
        mocked_call.return_value = {"reply": "听起来你今天很累。", "crisis": False}
        result = handle_api("POST", "/api/agent/emotional-support", json.dumps({
            "message": "最近有点累", "history": []
        }))
        self.assertEqual(200, result.status)
        self.assertEqual("听起来你今天很累。", result.payload["reply"])
        mocked_call.assert_called_once()


class FunctionGraphHandlerTests(unittest.TestCase):
    def test_health_event_returns_apig_response(self) -> None:
        response = handler({"httpMethod": "GET", "path": "/health"}, None)
        body = json.loads(response["body"])
        self.assertEqual(200, response["statusCode"])
        self.assertEqual("huawei-functiongraph", body["runtime"])
        self.assertFalse(response["isBase64Encoded"])

    def test_default_path_can_be_configured_per_trigger(self) -> None:
        previous = os.environ.get("FUNCTION_DEFAULT_PATH")
        os.environ["FUNCTION_DEFAULT_PATH"] = "/health"
        try:
            response = handler({"httpMethod": "GET"}, None)
        finally:
            if previous is None:
                os.environ.pop("FUNCTION_DEFAULT_PATH", None)
            else:
                os.environ["FUNCTION_DEFAULT_PATH"] = previous
        self.assertEqual(200, response["statusCode"])


if __name__ == "__main__":
    unittest.main()
