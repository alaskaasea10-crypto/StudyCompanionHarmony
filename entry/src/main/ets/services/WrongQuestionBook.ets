import { BankState, BankSession } from '../models/QuestionBankModels';
import { QuestionBank } from './QuestionBank';

export interface WrongQuestionEntry {
  id: string;
  skill: string;
  wrongAnswer: number;
  latestAnswer: number;
  wrongCount: number;
  corrected: boolean;
  transferCorrect: boolean;
}

// 从原始作答推导，不另存一份可能过期的错题状态。
export class WrongQuestionBook {
  static entries(state: BankState, topicId: string): WrongQuestionEntry[] {
    const sessions: BankSession[] = QuestionBank.sessions(state, topicId);
    const result: WrongQuestionEntry[] = [];
    for (const q of QuestionBank.all(topicId)) {
      let wrongAnswer: number = -1;
      let latestAnswer: number = -1;
      let wrongCount: number = 0;
      let lastWrongRound: number = -1;
      sessions.forEach((session: BankSession, round: number) => {
        const index: number = session.questionIds.indexOf(q.id);
        if (index >= 0 && index < session.answers.length) {
          latestAnswer = session.answers[index];
          if (latestAnswer !== q.answer) {
            wrongAnswer = latestAnswer;
            wrongCount++;
            lastWrongRound = round;
          }
        }
      });
      if (wrongCount === 0) { continue; }
      // 只认可最后一次出错之后、首次见到的同知识点不同题。
      const transferCorrect: boolean = QuestionBank.all(topicId).some((other) => {
        if (other.id === q.id || other.skill !== q.skill) { return false; }
        let firstRound: number = -1;
        let latest: number = -1;
        sessions.forEach((session: BankSession, round: number) => {
          const index: number = session.questionIds.indexOf(other.id);
          if (index >= 0 && index < session.answers.length) {
            if (firstRound < 0) { firstRound = round; }
            latest = session.answers[index];
          }
        });
        return firstRound > lastWrongRound && latest === other.answer;
      });
      result.push({ id: q.id, skill: q.skill, wrongAnswer: wrongAnswer, latestAnswer: latestAnswer,
        wrongCount: wrongCount, corrected: latestAnswer === q.answer, transferCorrect: transferCorrect });
    }
    return result;
  }

  static correction(state: BankState, topicId: string, id: string, now: number): BankState {
    const current: BankSession | undefined = QuestionBank.current(state, topicId);
    if (current !== undefined && current.answers.length < 3) { return state; }
    const q = QuestionBank.question(id);
    const skillIndex: number = QuestionBank.skills(topicId).indexOf(q.skill);
    if (skillIndex < 0 || !QuestionBank.all(topicId).some((item) => item.id === id)) {
      throw new Error('错题不属于当前专题');
    }
    const next: BankState = QuestionBank.start(state, now, topicId);
    const session: BankSession = next.sessions[next.sessions.length - 1];
    session.questionIds[skillIndex] = id;
    return next;
  }
}
