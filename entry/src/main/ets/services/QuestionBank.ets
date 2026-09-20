import { BankQuestion, BankSession, BankState, SkillEvidence, BankTopic } from '../models/QuestionBankModels';
import { RANK_QUESTIONS, DERIVATIVE_QUESTIONS } from './ExtendedBankQuestions';

// 原创练习；标准答案由 scripts/test-question-bank.cjs 独立数值/维度验算。
// 不是考试真题，不使用模型在线生成的答案进行判分。
const QUESTIONS: BankQuestion[] = [
  { id: 'mm-d1', skill: '乘法条件', prompt: 'A 是 2×3 矩阵，B 是 3×4 矩阵。AB 的形状是？',
    options: ['3×3', '2×4', '4×2', '不能相乘'], answer: 1,
    explanation: '内侧维度 3=3，所以可以相乘；结果保留 A 的行数与 B 的列数，即 2×4。',
    hints: ['你可能把内侧维度当成了结果形状。', '', '你可能交换了结果的行与列。', '矩阵不必同形，只需前者列数等于后者行数。'] },
  { id: 'mm-d2', skill: '乘法条件', prompt: 'A 是 3×2 矩阵，B 是 2×1 矩阵。以下哪项正确？',
    options: ['AB 为 3×1，BA 不存在', 'AB 与 BA 都存在', 'AB 不存在，BA 为 2×2', 'AB 为 2×2'], answer: 0,
    explanation: 'AB 的内侧维度为 2 与 2，结果 3×1；BA 的内侧维度为 1 与 3，不相等。',
    hints: ['', 'AB 存在不能推出 BA 也存在，需重新检查维度。', '判断时应沿书写顺序比较内侧维度。', '结果保留外侧维度，不是内侧维度。'] },
  { id: 'mm-d3', skill: '乘法条件', prompt: 'A 是 4×2 矩阵，AB 是 4×3 矩阵。B 必须是什么形状？',
    options: ['4×3', '3×2', '2×3', '2×4'], answer: 2,
    explanation: 'B 的行数要等于 A 的列数 2；B 的列数就是 AB 的列数 3，因此 B 为 2×3。',
    hints: ['乘积的行数来自 A，不能直接当成 B 的行数。', '你可能把 B 的行列颠倒了。', '', 'B 的列数应由乘积的列数确定。'] },
  { id: 'mm-c1', skill: '逐项计算', prompt: 'A = [[1, 2], [0, 1]]\nB = [[2, 0], [3, 1]]\nAB 的第 1 行第 1 列元素是？',
    options: ['2', '5', '8', '6'], answer: 2,
    explanation: '取 A 第 1 行 [1,2] 与 B 第 1 列 [2,3]：1×2 + 2×3 = 8。',
    hints: ['你可能只乘了对应位置，漏掉了第二项。', '应先对应相乘，再把乘积相加。', '', '你可能只保留了第二项 2×3。'] },
  { id: 'mm-c2', skill: '逐项计算', prompt: 'A = [[2, −1], [1, 3]]\nB = [[1, 4], [2, 0]]\nAB 的第 2 行第 1 列元素是？',
    options: ['9', '7', '2', '4'], answer: 1,
    explanation: '取 A 第 2 行 [1,3] 与 B 第 1 列 [1,2]：1×1 + 3×2 = 7。',
    hints: ['先确认所取的是第 2 行与第 1 列。', '', '这不是逐个位置相乘，需要把整行与整列配对。', '取 B 的第 1 列，而不是第 2 列。'] },
  { id: 'mm-c3', skill: '逐项计算', prompt: '行向量 [1, −2, 3] 乘以列向量 [4, 1, −1]ᵀ，结果是？',
    options: ['−1', '9', '3', '−9'], answer: 0,
    explanation: '1×4 + (−2)×1 + 3×(−1) = 4−2−3 = −1，结果为 1×1 矩阵。',
    hints: ['', '注意负数乘积的符号。', '最后一项为 −3，而不是 +3。', '第一项为正的 4，不能把所有项都变为负数。'] },
  { id: 'mm-c4', skill: '逐项计算', prompt: 'A = [[1, 2], [3, 4]]\nB = [[0, 1], [1, 0]]\nAB 等于？',
    options: ['[[3, 4], [1, 2]]', '[[0, 2], [3, 0]]', '[[1, 2], [3, 4]]', '[[2, 1], [4, 3]]'], answer: 3,
    explanation: '逐项计算得到 [[2,1],[4,3]]。右乘这个矩阵会交换 A 的两列；左乘才会交换两行。',
    hints: ['这是交换行的结果；这里 B 在右侧，会交换列。', '矩阵乘法不是对应位置逐项相乘。', 'B 不是单位矩阵，乘积不会保持 A 不变。', ''] },
  { id: 'mm-o1', skill: '运算顺序', prompt: '对列向量 x，先施加变换 A，再施加变换 B。合成结果应写成？',
    options: ['ABx', 'BAx', '(A+B)x', 'Ax+Bx'], answer: 1,
    explanation: '先得到 Ax，再让 B 作用于它：B(Ax) = (BA)x。靠近 x 的矩阵先作用。',
    hints: ['书写顺序与作用先后相反：离 x 最近的先作用。', '', '连续变换是矩阵相乘，不是相加。', '两次独立变换相加不是先后复合。'] },
  { id: 'mm-o2', skill: '运算顺序', prompt: 'A = [[1, 1], [0, 1]]\nB = [[1, 0], [1, 1]]\n关于 AB 与 BA，哪项正确？',
    options: ['所有方阵都有 AB=BA', 'AB 与 BA 都不存在', 'AB ≠ BA', 'AB=BA，因为它们同为 2×2'], answer: 2,
    explanation: 'AB=[[2,1],[1,1]]；BA=[[1,1],[1,2]]。虽然形状相同，元素不同，因此一般不能交换顺序。',
    hints: ['方阵也不一定满足交换律。', '两者内侧维度均为 2，所以都存在。', '', '形状相同不代表矩阵相等，还需逐项相等。'] },
  { id: 'mm-o3', skill: '运算顺序', prompt: 'A 为 2×3，B 为 3×4，C 为 4×1。哪项对任意这样的矩阵都成立？',
    options: ['(AB)C = A(BC)', '(AB)C = (BA)C', 'ABC = ACB', 'ABC 为 4×2'], answer: 0,
    explanation: '矩阵乘法满足结合律，能改变括号而不改变因子顺序；两边结果均为 2×1。BA 和 CB 在这里甚至无法相乘。',
    hints: ['', '结合律只改变括号，不交换 A 与 B。', '不能用结合律交换 B 与 C。', '结果形状由最外侧的 2 与 1 决定。'] }
];

export class QuestionBank {
  static topics(): BankTopic[] {
    return [
      { id:'matrix', title:'矩阵乘法', subject:'线性代数', prefix:'linear-algebra.matrix-multiplication',
        skills:['乘法条件','逐项计算','运算顺序'], keys:['dimensions','calculation','order'], videoModule:'matrix',
        reviews:['m×n 乘 n×p 得 m×p：内侧相等才能乘，外侧决定结果形状。','第 i 行第 j 列元素是 A 第 i 行与 B 第 j 列对应相乘后求和。','一般 AB≠BA；可以改括号，不能随意交换顺序。对列向量，最右侧变换先作用。'] },
      { id:'rank', title:'可逆矩阵与秩', subject:'线性代数', prefix:'linear-algebra.inverse-rank',
        skills:['可逆条件','秩的计算','方程与逆矩阵'], keys:['invertibility','rank','equations'], videoModule:'',
        reviews:['n 阶方阵可逆 ⇔ det(A)≠0 ⇔ rank(A)=n；前提必须是方阵。','用初等行变换化阶梯形，数主元或非零行；秩不超过行列数中的较小者。','Ax=0 的自由变量数为 n−rank(A)；用 AB=BA=I 检验逆矩阵，而不是逐个元素取倒数。'] },
      { id:'derivative', title:'导数与链式法则', subject:'高等数学', prefix:'calculus.derivatives',
        skills:['基本求导','链式法则','综合应用'], keys:['basics','chain','applications'], videoModule:'',
        reviews:['先求导再代入；(xⁿ)′=nxⁿ⁻¹，常数导数为 0，(ln x)′=1/x（x>0）。','复合函数外层求导、内层保持，再乘内层导数：(f(g(x)))′=f′(g(x))g′(x)。','乘积用 u′v+uv′；切线用 y−f(a)=f′(a)(x−a)。不要混淆函数值和斜率。'] }
    ];
  }
  static topic(id: string = 'matrix'): BankTopic {
    const topic: BankTopic | undefined = QuestionBank.topics().find((t: BankTopic) => t.id === id);
    if (topic === undefined) { throw new Error('Unknown topic'); }
    return topic;
  }
  static all(topicId: string = 'matrix'): BankQuestion[] {
    QuestionBank.topic(topicId);
    return topicId === 'matrix' ? QUESTIONS : topicId === 'rank' ? RANK_QUESTIONS : DERIVATIVE_QUESTIONS;
  }
  static skills(topicId: string = 'matrix'): string[] { return QuestionBank.topic(topicId).skills; }
  static question(id: string): BankQuestion {
    const q: BankQuestion | undefined = QUESTIONS.concat(RANK_QUESTIONS, DERIVATIVE_QUESTIONS).find((item: BankQuestion) => item.id === id);
    if (q === undefined) { throw new Error('Unknown question'); }
    return q;
  }
  static sessionTopic(s: BankSession): string {
    const id: string = s.questionIds[0] ?? '';
    return id.startsWith('rk-') ? 'rank' : id.startsWith('dv-') ? 'derivative' : 'matrix';
  }
  static sessions(state: BankState, topicId: string = 'matrix'): BankSession[] {
    return state.sessions.filter((s: BankSession) => QuestionBank.sessionTopic(s) === topicId);
  }
  static empty(): BankState { return { version: 1, sessions: [] }; }
  static current(state: BankState, topicId: string = 'matrix'): BankSession | undefined {
    const sessions: BankSession[] = QuestionBank.sessions(state, topicId);
    return sessions[sessions.length - 1];
  }
  static start(state: BankState, now: number, topicId: string = 'matrix'): BankState {
    const current: BankSession | undefined = QuestionBank.current(state, topicId);
    if (current !== undefined && current.answers.length < 3) { return state; }
    const seen: string[] = [];
    state.sessions.forEach((s: BankSession) => { s.questionIds.forEach((id: string) => { seen.push(id); }); });
    const ids: string[] = QuestionBank.skills(topicId).map((skill: string) => {
      const pool: BankQuestion[] = QuestionBank.all(topicId).filter((q: BankQuestion) => q.skill === skill);
      const fresh: BankQuestion | undefined = pool.find((q: BankQuestion) => !seen.includes(q.id));
      return (fresh ?? pool[QuestionBank.sessions(state, topicId).length % pool.length]).id;
    });
    const session: BankSession = { id: `${topicId}-${now}-${state.sessions.length}`, startedAt: now, questionIds: ids, answers: [] };
    return { version: 1, sessions: state.sessions.concat([session]) };
  }
  static answer(state: BankState, choice: number, topicId: string = 'matrix'): BankState {
    const current: BankSession | undefined = QuestionBank.current(state, topicId);
    if (current === undefined || current.answers.length >= 3 || !Number.isInteger(choice) || choice < 0 || choice > 3) { return state; }
    const next: BankSession = { id: current.id, startedAt: current.startedAt, questionIds: current.questionIds, answers: current.answers.concat([choice]) };
    return { version: 1, sessions: state.sessions.map((s: BankSession) => s.id === current.id ? next : s) };
  }
  static repeated(state: BankState, id: string): boolean {
    const topicId: string = id.startsWith('rk-') ? 'rank' : id.startsWith('dv-') ? 'derivative' : 'matrix';
    return QuestionBank.sessions(state, topicId).slice(0, -1).some((s: BankSession) => s.questionIds.includes(id));
  }
  static correctCount(session: BankSession): number {
    return session.answers.filter((answer: number, i: number) => answer === QuestionBank.question(session.questionIds[i]).answer).length;
  }
  static evidence(state: BankState, topicId: string = 'matrix'): SkillEvidence[] {
    return QuestionBank.skills(topicId).map((skill: string, index: number): SkillEvidence => {
      let total: number = 0;
      let correct: number = 0;
      // 每个题号只采用最近一次提交，重复答题不增加证据数量。
      QuestionBank.all(topicId).filter((q: BankQuestion) => q.skill === skill).forEach((q: BankQuestion) => {
        let latest: number = -1;
        state.sessions.forEach((s: BankSession) => {
          const i: number = s.questionIds.indexOf(q.id);
          if (i >= 0 && i < s.answers.length) { latest = s.answers[i]; }
        });
        if (latest >= 0) { total++; if (latest === q.answer) { correct++; } }
      });
      const status: string = total === 0 ? '待诊断' : correct < total ? '建议复习' : total < 2 ? '正在巩固' : '初步掌握';
      const review: string = QuestionBank.topic(topicId).reviews[index];
      return { skill: skill, status: status, correct: correct, total: total, review: review };
    });
  }
  static decode(raw: string): BankState {
    const value: BankState = JSON.parse(raw) as BankState;
    if (value === null || value.version !== 1 || !Array.isArray(value.sessions)) { throw new Error('Invalid bank records'); }
    const ids: string[] = [];
    value.sessions.forEach((s: BankSession, index: number) => {
      if (s === null || typeof s.id !== 'string' || ids.includes(s.id) || !Number.isFinite(s.startedAt) ||
        !Array.isArray(s.questionIds) || s.questionIds.length !== 3 || !Array.isArray(s.answers) || s.answers.length > 3) { throw new Error('Invalid session'); }
      const topicId: string = QuestionBank.sessionTopic(s);
      if (s.answers.length !== 3 && value.sessions.slice(index + 1).some((later: BankSession) =>
        later !== null && Array.isArray(later.questionIds) && QuestionBank.sessionTopic(later) === topicId)) { throw new Error('Unfinished session overwritten'); }
      ids.push(s.id);
      s.questionIds.forEach((id: string, i: number) => {
        if (!QuestionBank.all(topicId).some((q: BankQuestion) => q.id === id && q.skill === QuestionBank.skills(topicId)[i])) { throw new Error('Invalid question'); }
      });
      s.answers.forEach((a: number) => { if (!Number.isInteger(a) || a < 0 || a > 3) { throw new Error('Invalid answer'); } });
    });
    return value;
  }
}
