import base64
import unittest

from schedule_ocr import ScheduleOcrError, decode_image, parse_schedule_lines


class ScheduleOcrTests(unittest.TestCase):
    def test_parse_structured_lines(self) -> None:
        items = parse_schedule_lines([
            {"text": "周一 08:00-09:50 高等数学 @ 教学楼 A203"},
            {"text": "周三 14:00-15:50 数据结构实验 | 实验楼 C301"},
        ])
        self.assertEqual(2, len(items))
        self.assertEqual("高等数学", items[0]["course"])
        self.assertEqual(3, items[1]["weekday"])
        self.assertEqual("实验楼 C301", items[1]["location"])

    def test_parse_column_layout(self) -> None:
        lines = [
            {"text": "周一", "x": 0.20, "y": 0.05, "width": 0.08, "height": 0.03},
            {"text": "周二", "x": 0.42, "y": 0.05, "width": 0.08, "height": 0.03},
            {"text": "08:00-09:50", "x": 0.02, "y": 0.22, "width": 0.12, "height": 0.03},
            {"text": "高等数学", "x": 0.20, "y": 0.22, "width": 0.10, "height": 0.03},
            {"text": "教学楼A203", "x": 0.20, "y": 0.26, "width": 0.12, "height": 0.03},
            {"text": "大学英语", "x": 0.42, "y": 0.22, "width": 0.10, "height": 0.03},
        ]
        items = parse_schedule_lines(lines)
        self.assertEqual(2, len(items))
        self.assertEqual("教学楼A203", items[0]["location"])
        self.assertEqual(2, items[1]["weekday"])

    def test_parse_calendar_grid_with_single_character_weekdays(self) -> None:
        lines = []
        for index, day in enumerate((12, 13, 14, 15, 16, 17, 18)):
            lines.append({"text": str(day), "x": 0.12 + index * 0.10, "y": 0.12, "width": 0.03, "height": 0.02})
        for index, value in enumerate(("08:00", "08:45", "08:55", "09:40", "10:00", "10:45", "10:55", "11:40")):
            lines.append({"text": value, "x": 0.08, "y": 0.18 + index * 0.035, "width": 0.06, "height": 0.015})
        lines.extend([
            {"text": "高等数", "x": 0.12, "y": 0.19, "width": 0.07, "height": 0.015},
            {"text": "学", "x": 0.14, "y": 0.21, "width": 0.02, "height": 0.015},
            {"text": "@A203", "x": 0.12, "y": 0.23, "width": 0.07, "height": 0.015},
            {"text": "大学物", "x": 0.32, "y": 0.27, "width": 0.07, "height": 0.015},
            {"text": "理", "x": 0.34, "y": 0.29, "width": 0.02, "height": 0.015},
            {"text": "@FJ403", "x": 0.32, "y": 0.31, "width": 0.08, "height": 0.015},
        ])
        items = parse_schedule_lines(lines)
        self.assertEqual(2, len(items))
        self.assertEqual("高等数学", items[0]["course"])
        self.assertEqual("A203", items[0]["location"])
        self.assertEqual(3, items[1]["weekday"])

    def test_decode_rejects_invalid_image(self) -> None:
        with self.assertRaises(ScheduleOcrError):
            decode_image("not-base64")
        valid = base64.b64encode(b"x" * 100).decode()
        self.assertEqual(100, len(decode_image(valid)))

    def test_rejects_invalid_ocr_coordinates(self) -> None:
        with self.assertRaises(ScheduleOcrError):
            parse_schedule_lines([{"text": "周一", "x": "not-a-number"}])

    def test_rejects_invalid_course_time(self) -> None:
        with self.assertRaises(ScheduleOcrError):
            parse_schedule_lines([{"text": "周一 28:00-29:00 高等数学"}])


if __name__ == "__main__":
    unittest.main()
