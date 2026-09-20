import { BankLearningEvidence, BankSession, BankState, SkillEvidence, BankTopic } from '../models/QuestionBankModels';
import { AgentGeneratedTask, AgentPlan, AgentPlanRequest } from '../models/AgentModels';
import { QuestionBank } from './QuestionBank';
import { TodayPlanService } from './TodayPlanService';

export class BankLearningBridge {
  static summarize(state: BankState): BankLearningEvidence[] {
    const result: BankLearningEvidence[] = [];
    QuestionBank.topics().forEach((topic: BankTopic) => {
      const complete: BankSession[] = QuestionBank.sessions(state, topic.id).filter((s: BankSession) => s.answers.length === 3);
      if (complete.length === 0) { return; }
      const snapshot: BankState = { version: 1, sessions: complete };
      QuestionBank.evidence(snapshot, topic.id).forEach((e: SkillEvidence, index: number) => {
        result.push({
        topicId: topic.id, knowledgePointId: `${topic.prefix}.${topic.keys[index]}`,
        subject: topic.subject, knowledgePoint: `${topic.title} · ${e.skill}`, status: e.status,
        distinctQuestions: e.total, latestCorrect: e.correct,
        sessionStartedAt: complete[complete.length - 1].startedAt
        });
      });
    });
    return result;
  }

  static weakest(evidence: BankLearningEvidence[]): BankLearningEvidence | undefined {
    return evidence.filter((e: BankLearningEvidence) => e.status === '建议复习')
      .sort((a: BankLearningEvidence, b: BankLearningEvidence) =>
        (b.distinctQuestions - b.latestCorrect) - (a.distinctQuestions - a.latestCorrect))[0];
  }

  static reason(e: BankLearningEvidence): string {
    return `${e.knowledgePoint}：${e.distinctQuestions}道不同题最近${e.latestCorrect}道答对，${e.status}`;
  }

  static relevant(request: AgentPlanRequest): BankLearningEvidence[] {
    const subject: string = TodayPlanService.generate(request.requestText, request.profile.subject, 5).subject;
    const text: string = request.requestText;
    const topicId: string = /导数|求导|链式/.test(text) ? 'derivative' : /可逆|矩阵的秩|矩阵秩|与秩|逆矩阵/.test(text) ? 'rank' :
      text.includes('矩阵乘法') ? 'matrix' : request.context.bankTopicId ?? '';
    return (request.context.bankEvidence ?? []).filter((e: BankLearningEvidence) => e.subject === subject &&
      (topicId.length === 0 || BankLearningBridge.topicId(e) === topicId));
  }

  static topicId(e: BankLearningEvidence): string {
    return e.topicId ?? (e.knowledgePoint.includes('导数') ? 'derivative' : /可逆|与秩/.test(e.knowledgePoint) ? 'rank' : 'matrix');
  }

  // 模型输出和离线方案都经过这一步；只影响当前请求科目的薄弱点，不劫持其他学科规划。
  static prioritize(plan: AgentPlan, request: AgentPlanRequest): AgentPlan {
    const weak: BankLearningEvidence | undefined = BankLearningBridge.weakest(BankLearningBridge.relevant(request));
    if (weak === undefined) { return plan; }
    const reason: string = BankLearningBridge.reason(weak);
    const skill: string = weak.knowledgePoint.split('·').pop()?.trim() ?? weak.knowledgePoint;
    const topic: BankTopic = QuestionBank.topic(BankLearningBridge.topicId(weak));
    const matches = (task: AgentGeneratedTask): boolean => task.subject === weak.subject &&
      task.title.includes(skill) && (topic.id === 'derivative' ? /导数|求导|链式/.test(task.title) : /矩阵|秩/.test(task.title));
    const isQuiz = (task: AgentGeneratedTask): boolean => task.type === 'quiz' || /复测|小测/.test(task.title);
    const existingReview: AgentGeneratedTask | undefined = plan.tasks.find((task: AgentGeneratedTask) => matches(task) && !isQuiz(task));
    const existingQuiz: AgentGeneratedTask | undefined = plan.tasks.find((task: AgentGeneratedTask) =>
      matches(task) && isQuiz(task));
    const budget: number = Math.floor(request.context.availableMinutesToday);
    const canRetest: boolean = budget >= 10;
    const reviewMinutes: number = Math.min(15, Math.max(5, existingReview?.minutes ?? 15), canRetest ? budget - 5 : budget);
    const review: AgentGeneratedTask = {
      title: existingReview?.title ?? `针对复习：${weak.knowledgePoint}`, subject: weak.subject, type: 'review',
      minutes: reviewMinutes, priority: 1, reason: reason
    };
    const chosen: AgentGeneratedTask[] = [review];
    if (canRetest) {
      chosen.push({ title: existingQuiz?.title ?? `换题复测：${weak.knowledgePoint}`, subject: weak.subject, type: 'quiz',
        minutes: Math.min(Math.max(5, existingQuiz?.minutes ?? 5), budget - reviewMinutes), priority: 2,
        reason: '复习后用不同题目验证，不用观看记录替代答题证据' });
    }
    const rest: AgentGeneratedTask[] = plan.tasks.filter((task: AgentGeneratedTask) =>
      !matches(task) && !(task.subject === weak.subject && isQuiz(task)))
      .slice(0, 4 - chosen.length).map((task: AgentGeneratedTask, index: number): AgentGeneratedTask => {
        return { title: task.title, subject: task.subject, type: task.type, minutes: task.minutes,
          priority: index + chosen.length + 1, reason: task.reason };
      });
    return {
      summary: canRetest ? `先巩固${weak.knowledgePoint}，再换题复测` : `本次先巩固${weak.knowledgePoint}；时间不足，复测暂缓`, detectedSubject: weak.subject,
      recommendationReasons: [reason].concat(plan.recommendationReasons.filter((r: string) => r !== reason)),
      tasks: chosen.concat(rest), totalMinutes: 0, source: plan.source, model: plan.model, usage: plan.usage
    };
  }
}
