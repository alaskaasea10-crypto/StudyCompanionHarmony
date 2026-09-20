"""学伴本地 Agent 网关：密钥只保存在电脑端，不进入鸿蒙应用。"""

from __future__ import annotations

import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from agent_service import load_config
from api_router import ApiResult, handle_api, request_limit


class AgentRequestHandler(BaseHTTPRequestHandler):
    server_version = "StudyCompanionAgent/1.0"

    def do_GET(self) -> None:  # noqa: N802
        self._write_result(handle_api(
            "GET",
            self.path,
            enable_image_ocr=True,
            runtime_name="local-macos",
        ))

    def do_POST(self) -> None:  # noqa: N802
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except (TypeError, ValueError):
            content_length = 0
        if content_length <= 0 or content_length > request_limit(self.path):
            raw = b""
        else:
            raw = self.rfile.read(content_length)
        self._write_result(handle_api(
            "POST",
            self.path,
            raw,
            enable_image_ocr=True,
            runtime_name="local-macos",
        ))

    def log_message(self, format_string: str, *args: Any) -> None:
        print(f"[{self.log_date_time_string()}] {format_string % args}")

    def _write_result(self, result: ApiResult) -> None:
        body = result.body().encode("utf-8")
        self.send_response(result.status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    load_config(Path(__file__).with_name(".env"))
    # DevEco 模拟器通过 10.0.2.2 访问宿主机；监听所有本机网卡，
    # 否则服务只绑定 127.0.0.1 时，模拟器会一直显示离线方案。
    host = os.getenv("AGENT_BACKEND_HOST", "0.0.0.0")
    port = int(os.getenv("AGENT_BACKEND_PORT", "8000"))
    server = ThreadingHTTPServer((host, port), AgentRequestHandler)
    print(f"学伴 Agent 服务已启动：http://{host}:{port}")
    print("健康检查：/health；今日计划：POST /api/agent/today-plan；情绪陪伴：POST /api/agent/emotional-support；课表识别：POST /api/schedule/ocr")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n正在停止学伴 Agent 服务…")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
