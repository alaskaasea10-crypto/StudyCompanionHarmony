import { QuizQuestion } from '../models/AgentModels';

const LINEAR_ALGEBRA_QUESTION: QuizQuestion = {
  id: 'linear-algebra-invertible-01',
  subject: '线性代数',
  knowledgePoint: '可逆矩阵与秩',
  prompt: '若矩阵 A 可逆，下列结论正确的是？',
  optionA: 'det(A)=0',
  optionB: 'A 的列向量线性无关',
  optionC: 'A 没有逆矩阵',
  optionD: 'A 的秩小于列数',
  correctAnswer: 'B',
  explanation: '可逆矩阵满秩，因此列向量线性无关。'
};

const ENGLISH_QUESTION: QuizQuestion = {
  id: 'cet-vocabulary-context-01',
  subject: '英语四六级',
  knowledgePoint: '高频词汇语境',
  prompt: '在句子 “The new evidence may ___ the result.” 中，哪个词最合适？',
  optionA: 'affect',
  optionB: 'effect',
  optionC: 'effort',
  optionD: 'afford',
  correctAnswer: 'A',
  explanation: 'affect 是动词，表示“影响”；effect 通常作名词，表示“影响、效果”。'
};

const CALCULUS_QUESTION: QuizQuestion = {
  id: 'calculus-derivative-01',
  subject: '高等数学',
  knowledgePoint: '复合函数求导',
  prompt: '函数 y=sin(x²) 的导数是？',
  optionA: 'cos(x²)',
  optionB: '2x·cos(x²)',
  optionC: '2x·sin(x²)',
  optionD: 'cos(2x)',
  correctAnswer: 'B',
  explanation: '使用链式法则：外层导数为 cos(x²)，再乘以内层 x² 的导数 2x。'
};

const DATA_STRUCTURE_QUESTION: QuizQuestion = {
  id: 'data-structure-stack-01',
  subject: '数据结构',
  knowledgePoint: '栈的基本特性',
  prompt: '栈这种数据结构遵循哪种访问顺序？',
  optionA: '先进先出',
  optionB: '随机访问',
  optionC: '后进先出',
  optionD: '按关键字排序',
  correctAnswer: 'C',
  explanation: '栈遵循后进先出（LIFO），最后压入的元素最先弹出。'
};

const GENERAL_QUESTION: QuizQuestion = {
  id: 'general-active-recall-01',
  subject: '学习任务',
  knowledgePoint: '主动回忆',
  prompt: '完成一轮学习后，哪种方式更有助于检验是否真正掌握？',
  optionA: '立即重读全部内容',
  optionB: '合上资料主动复述关键点',
  optionC: '只标记已完成',
  optionD: '跳过反馈直接开始新章节',
  correctAnswer: 'B',
  explanation: '主动回忆能暴露记忆缺口，比单纯重读更适合检验掌握程度。'
};

export class QuizService {
  static questionFor(subject: string, taskTitle: string): QuizQuestion {
    const context: string = `${subject} ${taskTitle}`.toLowerCase();
    if (context.includes('英语') || context.includes('四六级') || context.includes('cet')) {
      return ENGLISH_QUESTION;
    }
    if (context.includes('线性代数') || context.includes('矩阵') || context.includes('行列式')) {
      return LINEAR_ALGEBRA_QUESTION;
    }
    if (context.includes('高等数学') || context.includes('高数') || context.includes('微积分')) {
      return CALCULUS_QUESTION;
    }
    if (context.includes('数据结构') || context.includes('算法')) {
      return DATA_STRUCTURE_QUESTION;
    }
    return GENERAL_QUESTION;
  }

  static questionById(questionId: string, subject: string, taskTitle: string): QuizQuestion {
    const questions: QuizQuestion[] = [
      LINEAR_ALGEBRA_QUESTION,
      ENGLISH_QUESTION,
      CALCULUS_QUESTION,
      DATA_STRUCTURE_QUESTION,
      GENERAL_QUESTION
    ];
    const stored: QuizQuestion | undefined = questions.find((question: QuizQuestion) => question.id === questionId);
    return stored ?? QuizService.questionFor(subject, taskTitle);
  }

  static isCorrect(question: QuizQuestion, answer: string): boolean {
    return answer === question.correctAnswer;
  }
}
