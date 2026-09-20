import { ScheduleItem } from './StudyModels';

export interface ScheduleOcrLine {
  text: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface ScheduleApiResponse {
  ok: boolean;
  source?: string;
  error?: string;
  recognizedLineCount?: number;
  scheduleItems?: ScheduleItem[];
}

export interface ScheduleImportResult {
  source: string;
  scheduleItems: ScheduleItem[];
}
