"""学伴后端共享 API 路由。

本地 ``app.py`` 与华为云 FunctionGraph 入口共同调用这里，避免两套部署方式
出现不同的参数校验和返回结构。云端默认不启用只在 macOS 上可用的 Vision OCR，
但仍支持解析 HarmonyOS Core Vision 返回的文字与坐标。
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from agent_service import (
    AgentServiceError,
    call_emotional_support,
    call_small_planet_reply,
    call_openpangu,
    load_config,
    validate_request,
    validate_support_request,
    validate_small_planet_request,
)
from schedule_ocr import ScheduleOcrError, parse_schedule_lines, recognize_schedule_image


JSON_HEADERS = {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
}
AGENT_MAX_BODY = 256_000
SCHEDULE_IMAGE_MAX_BODY = 12 * 1024 * 1024


@dataclass(frozen=True)
class ApiResult:
    status: int
    payload: dict[str, Any]

    def body(self) -> str:
        return json.dumps(self.payload, ensure_ascii=False, separators=(",", ":"))


def request_limit(path: str) -> int:
    normalized_path = path.split("?", 1)[0].rstrip("/") or "/"
    return SCHEDULE_IMAGE_MAX_BODY if normalized_path == "/api/schedule/ocr" else AGENT_MAX_BODY


def _error_status(error: AgentServiceError) -> int:
    message = str(error)
    return 503 if "openPangu" in message or "API_KEY" in message else 400


def _decode_payload(raw_body: bytes | str, path: str) -> Any:
    if isinstance(raw_body, str):
        body = raw_body.encode("utf-8")
    else:
        body = raw_body
    if not body or len(body) > request_limit(path):
        raise AgentServiceError("请求大小不正确")
    try:
        return json.loads(body.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise AgentServiceError("请求不是有效 JSON") from error


def handle_api(
    method: str,
    path: str,
    raw_body: bytes | str = b"",
    *,
    enable_image_ocr: bool = False,
    runtime_name: str = "functiongraph",
) -> ApiResult:
    """处理一次API请求并返回与运行容器无关的结果。"""

    normalized_method = method.upper().strip()
    normalized_path = path.split("?", 1)[0].rstrip("/") or "/"
    if normalized_method == "GET" and normalized_path == "/health":
        config = load_config()
        return ApiResult(
            200,
            {
                "ok": True,
                "service": "study-companion-agent",
                "runtime": runtime_name,
                "model": config.model,
                "configured": bool(config.api_key),
                "capabilities": {
                    "agentPlan": True,
                    "emotionalSupport": True,
                    "smallPlanetReply": True,
                    "scheduleLineParser": True,
                    "scheduleImageOcr": enable_image_ocr,
                },
            },
        )

    allowed_paths = {
        "/api/agent/today-plan",
        "/api/agent/emotional-support",
        "/api/agent/small-planet-reply",
        "/api/schedule/parse",
        "/api/schedule/ocr",
    }
    if normalized_method != "POST" or normalized_path not in allowed_paths:
        return ApiResult(404, {"ok": False, "error": "接口不存在"})

    try:
        payload = _decode_payload(raw_body, normalized_path)
        if normalized_path == "/api/agent/today-plan":
            data = validate_request(payload)
            result = call_openpangu(data, load_config())
            return ApiResult(200, {"ok": True, "plan": result})

        if normalized_path == "/api/agent/emotional-support":
            data = validate_support_request(payload)
            result = call_emotional_support(data, load_config())
            return ApiResult(200, {"ok": True, **result})

        if normalized_path == "/api/agent/small-planet-reply":
            data = validate_small_planet_request(payload)
            result = call_small_planet_reply(data, load_config())
            return ApiResult(200, {"ok": True, **result})

        if normalized_path == "/api/schedule/parse":
            lines = payload.get("lines", []) if isinstance(payload, dict) else []
            items = parse_schedule_lines(lines)
            if not items:
                raise ScheduleOcrError("识别到了文字，但没有解析出课程；请换一张包含星期和时间的完整截图")
            return ApiResult(200, {"ok": True, "source": "core-vision", "scheduleItems": items})

        if not enable_image_ocr:
            raise ScheduleOcrError("当前云端版本不接收整张图片，请优先使用鸿蒙端侧文字识别")
        image_base64 = payload.get("imageBase64", "") if isinstance(payload, dict) else ""
        lines, items = recognize_schedule_image(image_base64)
        if not items:
            raise ScheduleOcrError("识别到了文字，但没有解析出课程；请使用更清晰、完整的课表截图")
        return ApiResult(
            200,
            {
                "ok": True,
                "source": "macos-vision",
                "recognizedLineCount": len(lines),
                "scheduleItems": items,
            },
        )
    except AgentServiceError as error:
        return ApiResult(_error_status(error), {"ok": False, "error": str(error)})
    except ScheduleOcrError as error:
        return ApiResult(400, {"ok": False, "error": str(error)})
    except Exception as error:  # 不向客户端暴露堆栈或密钥相关信息
        print(f"Agent backend unexpected error: {type(error).__name__}: {error}")
        return ApiResult(500, {"ok": False, "error": "Agent 服务出现内部错误"})
