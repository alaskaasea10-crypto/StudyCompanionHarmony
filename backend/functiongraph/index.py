"""华为云 FunctionGraph 事件函数入口。

控制台处理器名称填写 ``index.handler``。APIG 触发器会把 HTTP 请求包装成
事件字典，本模块只负责还原请求，再交给共享 ``api_router`` 处理。
"""

from __future__ import annotations

import base64
import json
import os
from typing import Any

from api_router import ApiResult, JSON_HEADERS, handle_api


def _nested(value: Any, *keys: str) -> Any:
    current = value
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def _method(event: dict[str, Any]) -> str:
    candidates = (
        event.get("httpMethod"),
        event.get("method"),
        _nested(event, "requestContext", "http", "method"),
        _nested(event, "requestContext", "httpMethod"),
    )
    return next((str(value) for value in candidates if value), "GET")


def _path(event: dict[str, Any]) -> str:
    candidates = (
        event.get("path"),
        event.get("rawPath"),
        event.get("requestPath"),
        _nested(event, "requestContext", "http", "path"),
        _nested(event, "requestContext", "path"),
        os.getenv("FUNCTION_DEFAULT_PATH"),
    )
    return next((str(value) for value in candidates if value), "/health")


def _body(event: dict[str, Any]) -> bytes:
    value = event.get("body", b"")
    if isinstance(value, dict) or isinstance(value, list):
        return json.dumps(value, ensure_ascii=False).encode("utf-8")
    if isinstance(value, bytes):
        raw = value
    else:
        raw = str(value or "").encode("utf-8")
    if event.get("isBase64Encoded") is True and raw:
        try:
            return base64.b64decode(raw, validate=True)
        except (ValueError, TypeError):
            return b""
    return raw


def _response(result: ApiResult) -> dict[str, Any]:
    return {
        "statusCode": result.status,
        "headers": {
            **JSON_HEADERS,
            "X-Content-Type-Options": "nosniff",
        },
        "body": result.body(),
        "isBase64Encoded": False,
    }


def handler(event: Any, context: Any) -> dict[str, Any]:
    """FunctionGraph 处理器。API Key只从函数环境变量读取。"""

    if not isinstance(event, dict):
        return _response(ApiResult(400, {"ok": False, "error": "请求事件格式不正确"}))
    request_id = getattr(context, "request_id", "") if context is not None else ""
    if request_id:
        print(f"FunctionGraph request: {request_id}")
    return _response(handle_api(
        _method(event),
        _path(event),
        _body(event),
        enable_image_ocr=False,
        runtime_name="huawei-functiongraph",
    ))
