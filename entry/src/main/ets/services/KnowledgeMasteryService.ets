import { KnowledgeMastery } from '../models/StudyModels';

export class KnowledgeMasteryService {
  static statusFor(score: number): string {
    if (score >= 80) {
      return '已掌握';
    }
    if (score >= 60) {
      return '正在巩固';
    }
    return '需要复习';
  }

  static update(records: KnowledgeMastery[], subject: string, knowledgePoint: string,
    correct: boolean, updatedAt: number = Date.now()): KnowledgeMastery[] {
    const index: number = records.findIndex((item: KnowledgeMastery) => {
      return item.subject === subject && item.knowledgePoint === knowledgePoint;
    });
    const previous: KnowledgeMastery | undefined = index >= 0 ? records[index] : undefined;
    const previousScore: number = previous?.score ?? 50;
    const score: number = Math.min(100, Math.max(0, previousScore + (correct ? 18 : -22)));
    const next: KnowledgeMastery = {
      subject: subject,
      knowledgePoint: knowledgePoint,
      score: score,
      attemptCount: (previous?.attemptCount ?? 0) + 1,
      correctCount: (previous?.correctCount ?? 0) + (correct ? 1 : 0),
      status: KnowledgeMasteryService.statusFor(score),
      updatedAt: updatedAt
    };
    if (index < 0) {
      return records.concat([next]);
    }
    return records.map((item: KnowledgeMastery, itemIndex: number) => itemIndex === index ? next : item);
  }

  static latest(records: KnowledgeMastery[]): KnowledgeMastery | undefined {
    return records.slice().sort((left: KnowledgeMastery, right: KnowledgeMastery) => {
      return right.updatedAt - left.updatedAt;
    })[0];
  }

  static weakest(records: KnowledgeMastery[]): KnowledgeMastery | undefined {
    return records.slice().sort((left: KnowledgeMastery, right: KnowledgeMastery) => {
      if (left.score !== right.score) {
        return left.score - right.score;
      }
      return right.updatedAt - left.updatedAt;
    })[0];
  }
}
