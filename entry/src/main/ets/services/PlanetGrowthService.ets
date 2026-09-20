import { FocusRecord, QuizAttempt } from '../models/StudyModels';

export interface PlanetGrowth {
  level: number;
  experience: number;
  progress: number;
  remaining: number;
  stage: number;
  title: string;
}

export class PlanetGrowthService {
  static calculate(focus: FocusRecord[], quizzes: QuizAttempt[], bankDays: string[],
    now: number = Date.now()): PlanetGrowth {
    const candidates: string[] = bankDays.concat(
      focus.filter((item: FocusRecord) => item.elapsedSeconds >= 60).map((item: FocusRecord) => item.dayKey),
      quizzes.map((item: QuizAttempt) => item.dayKey));
    const today: string = new Date(now + 8 * 3600000).toISOString().substring(0, 10);
    const days: string[] = Array.from(new Set<string>(candidates.filter((day: string) => {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || day > today) { return false; }
      const time: number = Date.parse(day + 'T00:00:00Z');
      return Number.isFinite(time) && new Date(time).toISOString().substring(0, 10) === day;
    }))).sort();
    let experience: number = 0;
    let previous: number = 0;
    days.forEach((day: string, index: number) => {
      const time: number = Date.parse(day + 'T00:00:00Z');
      experience += 10 + (index > 0 && time - previous === 86400000 ? 5 : 0);
      previous = time;
    });
    const level: number = Math.floor(experience / 100) + 1;
    const stage: number = level >= 5 ? 3 : level >= 3 ? 2 : 1;
    return { level: level, experience: experience, progress: experience % 100,
      remaining: 100 - experience % 100, stage: stage,
      title: stage === 3 ? '星光相伴' : stage === 2 ? '微光同行' : '初生星球' };
  }
}
