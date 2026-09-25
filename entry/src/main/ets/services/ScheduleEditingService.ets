import { ScheduleItem } from '../models/StudyModels';

export class ScheduleEditingService {
  private static validTime(value: string): boolean {
    if (!/^\d{2}:\d{2}$/.test(value)) { return false; }
    const parts: string[] = value.split(':');
    const hour: number = Number(parts[0]);
    const minute: number = Number(parts[1]);
    return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
  }

  static copy(items: ScheduleItem[]): ScheduleItem[] {
    return items.map((item: ScheduleItem): ScheduleItem => ({
      id: item.id, weekday: item.weekday, startTime: item.startTime, endTime: item.endTime,
      course: item.course, location: item.location
    }));
  }

  static replace(items: ScheduleItem[], changed: ScheduleItem): ScheduleItem[] {
    return items.map((item: ScheduleItem): ScheduleItem => item.id === changed.id ? {
      id: item.id, weekday: changed.weekday, startTime: changed.startTime, endTime: changed.endTime,
      course: changed.course, location: changed.location
    } : item);
  }

  static add(items: ScheduleItem[], now: number = Date.now()): ScheduleItem[] {
    let suffix: number = 0;
    let id: string = `schedule-manual-${now}`;
    while (items.some((item: ScheduleItem) => item.id === id)) {
      suffix++;
      id = `schedule-manual-${now}-${suffix}`;
    }
    return items.concat([{ id: id, weekday: 1, startTime: '09:00', endTime: '10:00',
      course: '新课程', location: '' }]);
  }

  static remove(items: ScheduleItem[], id: string): ScheduleItem[] {
    if (items.length <= 1) { return items; }
    return items.filter((item: ScheduleItem) => item.id !== id);
  }

  static validationError(items: ScheduleItem[]): string {
    if (items.length === 0) { return '课表至少需要保留一门课程'; }
    const ids: string[] = [];
    for (const item of items) {
      if (item.id.trim().length === 0 || ids.includes(item.id)) { return '课程记录标识重复，请重新添加'; }
      ids.push(item.id);
      if (item.course.trim().length === 0) { return '请填写课程名称'; }
      if (item.weekday < 1 || item.weekday > 7) { return '请选择正确的星期'; }
      if (!ScheduleEditingService.validTime(item.startTime.trim()) ||
        !ScheduleEditingService.validTime(item.endTime.trim())) { return '上课时间请使用 HH:mm 格式'; }
      if (item.startTime.trim() >= item.endTime.trim()) { return '结束时间必须晚于开始时间'; }
    }
    return '';
  }

  static prepare(items: ScheduleItem[]): ScheduleItem[] | undefined {
    if (ScheduleEditingService.validationError(items).length > 0) { return undefined; }
    return ScheduleEditingService.copy(items).map((item: ScheduleItem): ScheduleItem => ({
      id: item.id, weekday: item.weekday, startTime: item.startTime.trim(), endTime: item.endTime.trim(),
      course: item.course.trim(), location: item.location.trim()
    })).sort((left: ScheduleItem, right: ScheduleItem): number =>
      left.weekday === right.weekday ? left.startTime.localeCompare(right.startTime) : left.weekday - right.weekday);
  }
}
