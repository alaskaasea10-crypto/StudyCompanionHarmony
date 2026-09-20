"""生成可上传到 FunctionGraph 的轻量部署包。"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


BACKEND_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = BACKEND_DIR / "dist"
OUTPUT_PATH = OUTPUT_DIR / "functiongraph-agent.zip"
PACKAGE_FILES = {
    BACKEND_DIR / "functiongraph" / "index.py": "index.py",
    BACKEND_DIR / "api_router.py": "api_router.py",
    BACKEND_DIR / "agent_service.py": "agent_service.py",
    BACKEND_DIR / "schedule_ocr.py": "schedule_ocr.py",
}


def build() -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUTPUT_PATH, "w", ZIP_DEFLATED) as archive:
        for source, destination in PACKAGE_FILES.items():
            if not source.exists():
                raise FileNotFoundError(f"部署文件不存在：{source}")
            archive.write(source, destination)
        archive.writestr(
            "deployment.json",
            json.dumps(
                {
                    "service": "study-companion-agent",
                    "handler": "index.handler",
                    "runtime": "Python 3.12",
                    "containsSecret": False,
                    "capabilities": ["health", "agent-plan", "schedule-line-parser"],
                },
                ensure_ascii=False,
                indent=2,
            ),
        )
    digest = hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest()
    print(f"已生成：{OUTPUT_PATH}")
    print(f"大小：{OUTPUT_PATH.stat().st_size} bytes")
    print(f"SHA-256：{digest}")
    return OUTPUT_PATH


if __name__ == "__main__":
    build()
