"""课表 OCR 与结构化解析。

识别引擎和解析规则刻意分离：鸿蒙真机可把 Core Vision 的行坐标传来；
模拟器开发时则由 macOS Vision 读取图片。两条路径最终进入同一解析器。
"""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


class ScheduleOcrError(ValueError):
    pass


@dataclass(frozen=True)
class OcrLine:
    text: str
    x: float = 0.0
    y: float = 0.0
    width: float = 0.0
    height: float = 0.0


WEEKDAYS = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7}
TIME_RE = re.compile(r"(?P<start>\d{1,2}[:：]\d{2})\s*[-~—–至]\s*(?P<end>\d{1,2}[:：]\d{2})")
STRUCTURED_RE = re.compile(
    r"周(?P<weekday>[一二三四五六日天])\s*"
    r"(?P<start>\d{1,2}[:：]\d{2})\s*[-~—–至]\s*(?P<end>\d{1,2}[:：]\d{2})\s*"
    r"(?P<course>[^@｜|·]+?)(?:\s*[@｜|·]\s*(?P<location>.+))?$"
)
LOCATION_HINTS = ("楼", "室", "馆", "校区", "教室", "实验", "线上", "体育场")
IGNORED_TEXT = ("课程表", "我的课表", "时间", "节次", "上午", "下午", "晚上", "完成")
IGNORED_CONTAINS = ("仅可访问", "隐私保护", "所有照片", "所有图片", "知乎")


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("：", ":")).strip(" |｜·")


def _time(value: str) -> str:
    hour, minute = value.replace("：", ":").split(":", 1)
    hour_value = int(hour)
    minute_value = int(minute)
    if not 0 <= hour_value <= 23 or not 0 <= minute_value <= 59:
        raise ScheduleOcrError("课表中包含无法识别的上课时间")
    return f"{hour_value:02d}:{minute_value:02d}"


def _line_from_json(value: Any) -> OcrLine:
    if not isinstance(value, dict):
        raise ScheduleOcrError("OCR 行格式不正确")
    try:
        return OcrLine(
            text=_clean(str(value.get("text", ""))),
            x=float(value.get("x", 0.0)),
            y=float(value.get("y", 0.0)),
            width=float(value.get("width", 0.0)),
            height=float(value.get("height", 0.0)),
        )
    except (TypeError, ValueError) as error:
        raise ScheduleOcrError("OCR 文字坐标格式不正确") from error


def normalize_lines(values: Iterable[Any]) -> list[OcrLine]:
    return [line for line in (_line_from_json(value) for value in values) if line.text]


def _weekday_in(text: str) -> int | None:
    match = re.search(r"(?:星期|周)([一二三四五六日天])", text)
    return WEEKDAYS.get(match.group(1)) if match else None


def _is_location(text: str) -> bool:
    return any(hint in text for hint in LOCATION_HINTS) and len(text) <= 32


def _is_candidate_course(text: str) -> bool:
    if len(text) < 2 or text in IGNORED_TEXT or _weekday_in(text) is not None:
        return False
    if TIME_RE.search(text) or re.fullmatch(r"第?\d+(?:[-~—–至]\d+)?节", text):
        return False
    if _is_location(text):
        return False
    return bool(re.search(r"[\u4e00-\u9fffA-Za-z]", text))


def _make_item(index: int, weekday: int, start: str, end: str, course: str, location: str) -> dict[str, Any]:
    return {
        "id": f"ocr-{weekday}-{_time(start).replace(':', '')}-{index}",
        "weekday": weekday,
        "startTime": _time(start),
        "endTime": _time(end),
        "course": _clean(course),
        "location": _clean(location) or "地点待确认",
    }


def _parse_structured(lines: list[OcrLine]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for line in lines:
        match = STRUCTURED_RE.search(line.text)
        if not match:
            continue
        result.append(
            _make_item(
                len(result), WEEKDAYS[match.group("weekday")], match.group("start"), match.group("end"),
                match.group("course"), match.group("location") or ""
            )
        )
    return result


def _parse_columns(lines: list[OcrLine]) -> list[dict[str, Any]]:
    headers: list[tuple[int, float]] = []
    for line in lines:
        weekday = _weekday_in(line.text)
        if weekday is not None:
            headers.append((weekday, line.x + line.width / 2))
    if not headers:
        return []

    time_lines: list[tuple[float, str, str]] = []
    for line in lines:
        match = TIME_RE.search(line.text)
        if match:
            time_lines.append((line.y + line.height / 2, match.group("start"), match.group("end")))

    result: list[dict[str, Any]] = []
    candidates = [line for line in lines if _is_candidate_course(line.text)]
    for line in candidates:
        center_x = line.x + line.width / 2
        weekday, distance = min(((day, abs(center_x - x)) for day, x in headers), key=lambda pair: pair[1])
        sorted_x = sorted(x for _, x in headers)
        column_width = (sorted_x[-1] - sorted_x[0]) / max(1, len(sorted_x) - 1)
        if len(headers) > 1 and distance > max(0.09, column_width * 0.65):
            continue
        center_y = line.y + line.height / 2
        inline_time = TIME_RE.search(line.text)
        if inline_time:
            start, end = inline_time.group("start"), inline_time.group("end")
            course = TIME_RE.sub("", line.text).strip()
        elif time_lines:
            _, start, end = min(time_lines, key=lambda value: abs(center_y - value[0]))
            course = line.text
        else:
            continue
        nearby_locations = [
            other for other in lines
            if _is_location(other.text)
            and abs((other.x + other.width / 2) - center_x) < max(0.12, column_width * 0.65)
            and abs((other.y + other.height / 2) - center_y) < 0.1
        ]
        location = min(nearby_locations, key=lambda other: abs(other.y - line.y)).text if nearby_locations else ""
        if course:
            result.append(_make_item(len(result), weekday, start, end, course, location))
    return result


def _date_column_headers(lines: list[OcrLine]) -> tuple[list[tuple[int, float]], float] | None:
    """从同一行连续出现的 7 个日期数字推断星期列。

    许多高校课表只把星期显示成单个“一、二、三”，Vision 容易漏掉其中几个，
    但下方连续的日期通常都能识别。日期只用于定位列，不作为课程数据保存。
    """
    date_lines = [
        line for line in lines
        if re.fullmatch(r"(?:[1-9]|[12]\d|3[01])", line.text)
        and line.x > 0.08 and line.width < 0.09
    ]
    groups: list[list[OcrLine]] = []
    for line in sorted(date_lines, key=lambda value: value.y):
        matching = next(
            (group for group in groups if abs(line.y - sum(item.y for item in group) / len(group)) < 0.022),
            None,
        )
        if matching is None:
            groups.append([line])
        else:
            matching.append(line)
    candidates: list[list[OcrLine]] = []
    for group in groups:
        ordered = sorted(group, key=lambda value: value.x)
        unique: list[OcrLine] = []
        for line in ordered:
            if not unique or abs((line.x + line.width / 2) - (unique[-1].x + unique[-1].width / 2)) > 0.035:
                unique.append(line)
        if len(unique) >= 6 and unique[-1].x - unique[0].x > 0.42:
            candidates.append(unique)
    if not candidates:
        return None
    selected = max(candidates, key=lambda group: (len(group), group[-1].x - group[0].x))
    if len(selected) > 7:
        selected = selected[:7]
    if len(selected) != 7:
        return None
    header_y = sum(line.y + line.height / 2 for line in selected) / len(selected)
    return ([(index + 1, line.x + line.width / 2) for index, line in enumerate(selected)], header_y)


def _grid_headers(lines: list[OcrLine]) -> tuple[list[tuple[int, float]], float] | None:
    date_headers = _date_column_headers(lines)
    if date_headers is not None:
        return date_headers
    weekday_lines: list[tuple[int, OcrLine]] = []
    for line in lines:
        text = line.text.strip()
        weekday = WEEKDAYS.get(text) if len(text) == 1 else _weekday_in(text)
        if weekday is not None:
            weekday_lines.append((weekday, line))
    if len(weekday_lines) < 5:
        return None
    header_y = sum(line.y + line.height / 2 for _, line in weekday_lines) / len(weekday_lines)
    return ([(weekday, line.x + line.width / 2) for weekday, line in weekday_lines], header_y)


def _grid_time_windows(lines: list[OcrLine], left_column_x: float, header_y: float) -> list[tuple[float, str, str]]:
    points: list[tuple[float, str]] = []
    for line in lines:
        if line.x >= left_column_x - 0.035 or line.y <= header_y:
            continue
        if not re.fullmatch(r"\d{1,2}[:：]\d{2}", line.text):
            continue
        value = _time(line.text)
        center_y = line.y + line.height / 2
        if not any(existing == value and abs(existing_y - center_y) < 0.01 for existing_y, existing in points):
            points.append((center_y, value))
    points.sort(key=lambda value: value[0])
    periods: list[tuple[float, str, str]] = []
    for index in range(0, len(points) - 1, 2):
        start_y, start = points[index]
        end_y, end = points[index + 1]
        periods.append(((start_y + end_y) / 2, start, end))
    windows: list[tuple[float, str, str]] = []
    for index in range(0, len(periods), 2):
        first = periods[index]
        last = periods[min(index + 1, len(periods) - 1)]
        windows.append(((first[0] + last[0]) / 2, first[1], last[2]))
    return windows


def _is_grid_fragment(line: OcrLine, header_y: float, table_bottom: float) -> bool:
    text = line.text.strip()
    if line.y <= header_y + 0.012 or line.y >= table_bottom:
        return False
    if not text or text in IGNORED_TEXT or any(value in text for value in IGNORED_CONTAINS):
        return False
    if TIME_RE.search(text) or re.fullmatch(r"\d{1,2}[:：]\d{2}", text):
        return False
    if re.fullmatch(r"(?:星期|周)?[一二三四五六日天]", text):
        return False
    return bool(re.search(r"[\u4e00-\u9fffA-Za-z@\d]", text))


def _course_and_location(fragments: list[OcrLine]) -> tuple[str, str]:
    ordered = sorted(fragments, key=lambda line: (line.y, line.x))
    text = "".join(_clean(line.text).replace(" ", "") for line in ordered)
    if "@" in text:
        course, location = text.split("@", 1)
    else:
        course, location = text, ""
    course = re.sub(r"^(?:第?\d+(?:[-~—–至]\d+)?节)+", "", course)
    course = course.strip("-—|｜·@")
    location = location.strip("-—|｜·@")
    return course, location


def _parse_calendar_grid(lines: list[OcrLine]) -> list[dict[str, Any]]:
    header_result = _grid_headers(lines)
    if header_result is None:
        return []
    headers, header_y = header_result
    headers = sorted(headers, key=lambda value: value[0])
    x_values = sorted(x for _, x in headers)
    if len(x_values) < 2:
        return []
    column_width = (x_values[-1] - x_values[0]) / max(1, len(x_values) - 1)
    windows = _grid_time_windows(lines, x_values[0], header_y)
    if not windows:
        return []
    time_lines = [
        line for line in lines
        if re.fullmatch(r"\d{1,2}[:：]\d{2}", line.text) and line.x < x_values[0] - 0.035
    ]
    table_bottom = max((line.y + line.height for line in time_lines), default=1.0) + 0.035
    by_day: dict[int, list[OcrLine]] = {day: [] for day, _ in headers}
    for line in lines:
        if not _is_grid_fragment(line, header_y, table_bottom):
            continue
        center_x = line.x + line.width / 2
        weekday, distance = min(((day, abs(center_x - x)) for day, x in headers), key=lambda value: value[1])
        if distance <= column_width * 0.48:
            by_day[weekday].append(line)

    result: list[dict[str, Any]] = []
    for weekday, fragments in by_day.items():
        ordered = sorted(fragments, key=lambda line: (line.y, line.x))
        blocks: list[list[OcrLine]] = []
        for line in ordered:
            if not blocks:
                blocks.append([line])
                continue
            previous_bottom = max(value.y + value.height for value in blocks[-1])
            if line.y - previous_bottom <= 0.037:
                blocks[-1].append(line)
            else:
                blocks.append([line])
        for block in blocks:
            course, location = _course_and_location(block)
            if len(course) < 2 or not re.search(r"[\u4e00-\u9fffA-Za-z]", course):
                continue
            top = min(line.y for line in block)
            bottom = max(line.y + line.height for line in block)
            center_y = (top + bottom) / 2
            _, start, end = min(windows, key=lambda value: abs(center_y - value[0]))
            result.append(_make_item(len(result), weekday, start, end, course, location))
    return result


def parse_schedule_lines(values: Iterable[Any]) -> list[dict[str, Any]]:
    lines = normalize_lines(values)
    result = _parse_structured(lines)
    if not result:
        result = _parse_calendar_grid(lines)
    if not result:
        result = _parse_columns(lines)
    unique: dict[tuple[int, str, str], dict[str, Any]] = {}
    for item in result:
        unique[(item["weekday"], item["startTime"], item["course"])] = item
    items = list(unique.values())
    items.sort(key=lambda item: (item["weekday"], item["startTime"], item["course"]))
    for index, item in enumerate(items):
        item["id"] = f"ocr-{item['weekday']}-{item['startTime'].replace(':', '')}-{index}"
    return items


def decode_image(image_base64: str) -> bytes:
    if not image_base64:
        raise ScheduleOcrError("没有收到课表图片")
    if "," in image_base64:
        image_base64 = image_base64.split(",", 1)[1]
    try:
        image_bytes = base64.b64decode(image_base64, validate=True)
    except Exception as error:
        raise ScheduleOcrError("课表图片编码无效") from error
    if not 100 <= len(image_bytes) <= 8 * 1024 * 1024:
        raise ScheduleOcrError("图片大小需在 100B 到 8MB 之间")
    return image_bytes


def recognize_with_macos_vision(image_bytes: bytes) -> list[dict[str, Any]]:
    helper = Path(__file__).with_name("macos_vision_ocr.swift")
    if not helper.exists():
        raise ScheduleOcrError("本机 OCR 助手缺失")
    image_file = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    image_path = image_file.name
    try:
        image_file.write(image_bytes)
        image_file.close()
        os.chmod(image_path, 0o644)
        try:
            process = subprocess.run(
                ["xcrun", "swift", str(helper), image_path], capture_output=True, text=True, timeout=45, check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise ScheduleOcrError("本机 OCR 识别超时，请压缩图片或换一张更清晰的截图") from error
        except OSError as error:
            raise ScheduleOcrError("无法启动本机 OCR，请确认已安装 Xcode 命令行工具") from error
    finally:
        Path(image_path).unlink(missing_ok=True)
    if process.returncode != 0:
        raise ScheduleOcrError("本机 OCR 识别失败，请使用真机或更清晰的课表截图")
    try:
        payload = json.loads(process.stdout)
    except json.JSONDecodeError as error:
        raise ScheduleOcrError("本机 OCR 返回格式异常") from error
    if not isinstance(payload, list):
        raise ScheduleOcrError("本机 OCR 未返回文字行")
    return payload


def recognize_schedule_image(image_base64: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    lines = recognize_with_macos_vision(decode_image(image_base64))
    return lines, parse_schedule_lines(lines)
