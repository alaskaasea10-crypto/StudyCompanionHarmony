import { AcademicGoal, StudyStateSnapshot, StudyTask, TodayIntent, TodayStudyOverride } from '../models/StudyModels';
import { AgentDecisionService } from './AgentDecisionService';
import { GoalPlanningService } from './GoalPlanningService';
import { LearningActionService } from './LearningActionService';
import { LearningDecisionPolicy } from './LearningDecisionPolicy';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';
import { PlanValidator } from './PlanValidator';
import { StudyDecisionDebug } from './StudyDecisionDebug';
import { subjectAliases } from '../utils/SubjectDisplayName';

export interface TodayIntentResolution {
  kind: string;
  intent: TodayIntent;
  override?: TodayStudyOverride;
  createdTasks?: StudyTask[];
  message: string;
}

// 先解析，再产生待校验的增量；此服务不直接写存储，不修改已有任务。
export class TodayIntentService {
  private static explanation(text: string): boolean {
    return /(?:为什么|为何).*(?:安排|计划|建议|先学|先做|这个)/.test(text) ||
      /(?:这个|这样|当前).*(?:安排|计划|建议).*(?:合理|合适|原因)/.test(text) ||
      /(?:看不懂|不理解|没明白|不太懂).*(?:安排|计划|建议)/.test(text);
  }

  private static additiveSubjects(text: string): string[] {
    const subjects: string[] = TodayStudyOverrideService.subjectsIn(text);
    if (subjects.length < 2 || !/(?:也|还想|都学|不只|别全学|除了).*(?:学|复习)|别全学/.test(text)) {
      return [];
    }
    return subjects;
  }

  private static subject(text: string, tasks: StudyTask[]): string {
    const aliases: string[] = subjectAliases();
    tasks.forEach((task: StudyTask) => {
      const name: string = TodayStudyOverrideService.subjectName(task.subject);
      if (!aliases.includes(name)) { aliases.push(name); }
    });
    let subject: string = '';
    let latest: number = -1;
    aliases.forEach((alias: string) => {
      const index: number = text.toLowerCase().lastIndexOf(alias.toLowerCase());
      if (index < 0) { return; }
      const prefix: string = text.substring(Math.max(0, index - 10), index);
      if (/(不想|不再|不要|别|不学|不复习)[^，。！？,;；]*(?:要不|还是|改学|今天学|今晚学)/.test(prefix)) {
        // 转折后的正向指令继续处理。
      } else if (/(不想|不再|不要|别|不学|不复习)[^，。！？,;；]*$/.test(prefix)) { return; }
      if (index > latest) { latest = index; subject = TodayStudyOverrideService.subjectName(alias); }
    });
    if (subject.length === 0 && !/(不想|不要|不学|不复习|别学)/.test(text)) {
      const match: RegExpMatchArray | null = text.match(/(?:复习|学习|今天学|现在学)([^，。！？,\d]{1,16}?)(?:吧|了|。|，|$)/);
      if (match !== null && !/任务|计划|安排|进程|一下|什么|多久|内容/.test(match[1])) { subject = match[1].trim(); }
    }
    return subject;
  }

  private static topic(text: string, subject: string): string {
    const words: string[] = text.split(/[，。！？,;；]/);
    for (const clause of words) {
      if (TodayIntentService.subject(clause, []) !== subject) { continue; }
      const normalized: string = clause.replace(/AdvancedMath|高数/g, '高等数学')
        .replace(/LinearAlgebra|线代/g, '线性代数').replace(/CollegeEnglish/g, '大学英语');
      const offset: number = normalized.indexOf(subject);
      if (offset < 0) { return /单词/.test(clause) ? '单词' : ''; }
      const tail: string = normalized.substring(offset + subject.length)
        .replace(/\d+\s*分钟|半小时|[一二两三四五]\s*小时/g, '')
        .replace(/^(的|学|复习|学习|重新|再)+/, '')
        .replace(/(重新过一遍|过一遍|重新复习|复习|学习|吧|了|大概|大约|先|一下|题|练习|做题)+$/g, '').trim();
      if (tail.length > 0 && tail.length <= 16 && !/怎么|什么|好难|考试|分钟|小时/.test(tail)) { return tail; }
    }
    return /单词/.test(text) ? '单词' : '';
  }

  private static newTasks(snapshot: StudyStateSnapshot, intent: TodayIntent, strategy: boolean,
    now: number): StudyTask[] {
    const subject: string = TodayStudyOverrideService.subjectName(intent.subject ?? '');
    const target: string = subject + (intent.topic ? ` · ${intent.topic}` : '');
    const verb: string = intent.activity === 'memorize' ? '背诵' : intent.activity === 'practice' ? '练习' :
      intent.activity === 'preview' ? '预习' : '复习';
    const titles: string[] = strategy ? [`回顾${target}的概念与笔记`, `练习${target}并核对解题过程`,
      `整理${target}仍不清楚的问题`] : [`${verb}${target}`];
    const requested: number = intent.requestedMinutes ?? (strategy ? 45 : 25);
    const ids: string[] = (snapshot.tasks ?? []).map((task: StudyTask) => task.id ?? '').concat(snapshot.deletedTaskIds ?? []);
    const result: StudyTask[] = [];
    let remaining: number = requested;
    titles.forEach((title: string, index: number) => {
      if (remaining < 5) { return; }
      let suffix: number = snapshot.tasks.length + index;
      let id: string = `today-agent-${now}-${suffix}`;
      while (ids.includes(id)) { suffix++; id = `today-agent-${now}-${suffix}`; }
      ids.push(id);
      const minutes: number = Math.min(45, remaining, strategy ? [15, 20, 10][index] : requested);
      result.push({ id: id, title: title, subject: subject, minutes: minutes, completed: false,
        source: 'today-temporary', createdAt: now, completedAt: 0 });
      remaining -= minutes;
    });
    return result;
  }

  static resolve(text: string, snapshot: StudyStateSnapshot, now: number = Date.now(),
    confirmStrategy: boolean = false): TodayIntentResolution {
    const message: string = text.trim();
    const intent: TodayIntent = { action: 'plan', scope: message.includes('现在') ? 'now' : 'today',
      source: 'user-chat' };
    if (/^(返回上一步|撤销|撤回上一步|撤销上一步)[。！!\s]*$/.test(message)) {
      return { kind: 'undo', intent: intent, message: '' };
    }
    // 对已经存在的安排进行解释或讨论只读取当前决策，不得误命中“先学某科”而改写今日状态。
    if (TodayIntentService.explanation(message)) {
      intent.action = 'explain';
      return { kind: 'explain', intent: intent, message: TodayIntentService.explain(snapshot, now) };
    }
    if (/(什么时候|哪天|还有多久|还有几天|剩几天)/.test(message) && /(考试|目标|截止)/.test(message)) {
      intent.subject = TodayIntentService.subject(message, snapshot.tasks ?? []);
      return { kind: 'reminder', intent: intent, message: TodayIntentService.reminder(snapshot, intent.subject, now) };
    }
    if (/(后续|接下来|今天|后面).*(列出来|看看|查看|列出)/.test(message)) {
      return { kind: 'show', intent: intent, message: TodayIntentService.describe(snapshot, now) };
    }
    const additiveSubjects: string[] = TodayIntentService.additiveSubjects(message);
    if (additiveSubjects.length > 1) {
      intent.action = 'clarify';
      return { kind: 'clarify', intent: intent,
        message: `我听懂你想保留${additiveSubjects[0]}，也加入${additiveSubjects[1]}。为了不把“都学”误改成只学一科，我还没有替换当前安排。你想先学哪一科？` };
    }
    // 已完成/已删除的历史任务只能作为记录，不能截获用户今天再次提出的同名学习意图。
    // 否则“我想复习高等数学”会命中昨天或刚完成的同名任务，继而无法创建今天的新行动。
    const titles: StudyTask[] = (snapshot.tasks ?? []).filter((task: StudyTask) => task.id !== undefined &&
      !task.completed && !(snapshot.deletedTaskIds ?? []).includes(task.id ?? '') &&
      task.title.trim().length > 0 && message.includes(task.title));
    const uniqueTitles: StudyTask[] = titles.filter((task: StudyTask) => !titles.some((other: StudyTask) =>
      other.title.length > task.title.length && other.title.includes(task.title)));
    if (uniqueTitles.length > 1) {
      return { kind: 'clarify', intent: intent, message: '这句话对应多个真实任务，请一次指定一项任务，或在“调整今天安排”中选择。' };
    }
    const selected: StudyTask | undefined = uniqueTitles[0];
    const parsedSubject: string = TodayIntentService.subject(message, snapshot.tasks ?? []);
    if (selected !== undefined && parsedSubject && TodayStudyOverrideService.subjectName(selected.subject) !== parsedSubject) {
      return { kind: 'clarify', intent: intent, message: '这项任务保存的科目与名称不一致，请先确认任务；我没有把它换成另一科。' };
    }
    let subject: string = parsedSubject || (selected ? TodayStudyOverrideService.subjectName(selected.subject) : '');
    const minutes: number = LearningDecisionPolicy.requestedMinutes(message);
    const zeroMinutes: boolean = /(?:只有|剩|还能|时间|学习)\s*0\s*分钟/.test(message);
    if (subject.length > 0) { intent.subject = subject; }
    intent.activity = /背|单词/.test(message) ? 'memorize' : /做.*题|练习/.test(message) ? 'practice' :
      /预习/.test(message) ? 'preview' : 'review';
    if (selected !== undefined) { intent.taskId = selected.id; }
    if (minutes > 0 || zeroMinutes) { intent.requestedMinutes = minutes; }
    intent.minutesKind = /今天|今晚|现在|只有|剩|还能|半小时.*(?:学|复习)/.test(message) || !subject ? 'budget' : 'task';
    const strategy: boolean = /怎么(?:学|复习|开始)|如何|不知道|不会安排|学习方法|学习方案|拆解/.test(message);
    const contextualSubject: string = TodayStudyOverrideService.subjectName(
      TodayStudyOverrideService.active(snapshot, now)?.intent?.subject ??
      TodayStudyOverrideService.active(snapshot, now)?.preferredSubject ?? '');
    if (!subject && strategy && contextualSubject) {
      subject = contextualSubject;
      intent.subject = contextualSubject;
    }
    if (!subject && /(?:先学什么|从哪开始|接下来做什么|下一步)/.test(message)) {
      return { kind: 'show', intent: intent, message: TodayIntentService.describe(snapshot, now) };
    }
    const executable: boolean = !strategy && !/是什么|好难|怎么办|累|心情|状态不好|陪我/.test(message) &&
      (/复习|学习|(?:今天|今晚|现在|接下来|还是|改|想|先)学|学\s*\d+|做.*题|背.*单词/.test(message) ||
        (!!subject && minutes > 0 && /今天|今晚|现在/.test(message)) ||
        (!!subject && /吧[。！!\s]*$/.test(message)) ||
        (!!subject && /还是|改成|换成|就选|算了/.test(message)));
    if (strategy && subject) {
      intent.action = 'strategy'; intent.topic = TodayIntentService.topic(message, subject);
      if (!confirmStrategy) {
        const proposals: StudyTask[] = TodayIntentService.newTasks(snapshot, intent, true, now);
        return { kind: 'strategy', intent: intent, message: `可以从这几步开始（建议，尚未加入今天）：\n${
          proposals.map((task: StudyTask, index: number) => `${index + 1}. ${task.title} · ${task.minutes}分钟`).join('\n')
          }\n这些是学习方法建议，不代表你已经掌握或缺少哪些知识。回复“就按这个安排”，我会先复用已有同科任务，再把需要的步骤加入今天；联网时会继续请小星球结合真实任务细化安排。` };
      }
    } else if (subject && !executable && selected === undefined) {
      return { kind: 'clarify', intent: intent, message: `听起来${subject}让你有些困惑。可以告诉我卡在哪一步，或说“我不知道${subject}怎么复习”，我们一起拆开来做。今天的安排没有改变。` };
    }
    if (!subject && TodayStudyOverrideService.subjectsIn(message).length > 0 &&
      /(不想|不要|不学|别学)/.test(message)) {
      return { kind: 'clarify', intent: intent, message: '那今天想换成哪一科？我先保留当前安排，不会创建你不想学的任务。' };
    }
    if (!subject && /不想学太久|少学一会|时间不多|有点累/.test(message)) {
      return { kind: 'clarify', intent: intent,
        message: '可以，我们把今天放轻一点。你从现在起还愿意学习多少分钟？我会保留已有任务，等你确认时间后再调整。' };
    }
    if (subject.length === 0 && intent.requestedMinutes === undefined && selected === undefined) {
      return /安排|规划|计划|学习/.test(message) ? { kind: 'plan', intent: intent, message: '' } :
        { kind: 'clarify', intent: intent, message: '我在。你可以说说哪里卡住了，也可以切到“陪我聊聊”。今天的安排没有改变。' };
    }
    const active: TodayStudyOverride = TodayStudyOverrideService.active(snapshot, now) ??
      { date: TodayStudyOverrideService.date(now) };
    const next: TodayStudyOverride = JSON.parse(JSON.stringify(active)) as TodayStudyOverride;
    const merged: TodayIntent = JSON.parse(JSON.stringify(active.intent ?? intent)) as TodayIntent;
    merged.action = strategy ? 'strategy' : 'execute'; merged.scope = intent.scope; merged.source = 'user-chat';
    if (intent.subject !== undefined) {
      merged.subject = intent.subject;
      merged.taskId = intent.taskId;
      next.preferredTaskId = intent.taskId ?? '';
      next.preferredSubject = intent.subject;
      next.suggestedTaskIds = undefined; next.suggestedTaskMinutes = undefined;
      merged.topic = TodayIntentService.topic(message, intent.subject);
      merged.activity = intent.activity;
      // 切换科目时，不把旧的单任务时长带给新科目；当天预算仍保留。
      merged.requestedMinutes = undefined; merged.minutesKind = undefined;
    }
    if (intent.requestedMinutes !== undefined) {
      merged.requestedMinutes = intent.requestedMinutes;
      merged.minutesKind = intent.minutesKind;
      if (intent.minutesKind === 'budget') {
        next.availableMinutes = LearningActionService.totalBudgetForAdditional(snapshot, intent.requestedMinutes, now);
      }
    }
    next.intent = merged;
    if (intent.subject !== undefined) {
      const reusableTodayIds: string[] = snapshot.tasks.filter((task: StudyTask) =>
        task.source === 'today-temporary' && !task.completed && task.createdAt !== undefined &&
        TodayStudyOverrideService.date(task.createdAt) === next.date &&
        TodayStudyOverrideService.subjectName(task.subject) === intent.subject &&
        !(snapshot.deletedTaskIds ?? []).includes(task.id ?? ''))
        .map((task: StudyTask) => task.id ?? '');
      next.temporaryTaskIds = Array.from(new Set((next.temporaryTaskIds ?? []).concat(reusableTodayIds)));
    }
    const projected: StudyStateSnapshot = JSON.parse(JSON.stringify(snapshot)) as StudyStateSnapshot;
    projected.todayStudyOverride = next;
    const candidates = LearningActionService.candidates(projected, now);
    const matching = merged.topic ? candidates.filter(item => item.task.title.includes(merged.topic ?? '')) : candidates;
    if (selected !== undefined && !candidates.some(item => item.task.id === selected.id)) {
      return { kind: 'clarify', intent: intent,
        message: '这项任务已经完成、今日跳过、暂缓或正待反馈；我没有重新激活它，请先处理现有状态。' };
    }
    let added: StudyTask[] = [];
    if (intent.subject !== undefined && selected === undefined) {
      next.preferredTaskId = matching[0]?.task.id ?? '';
      if (next.preferredTaskId.length === 0) {
        const protectedTask: StudyTask | undefined = (snapshot.tasks ?? []).find((task: StudyTask, index: number) =>
          !task.completed && TodayStudyOverrideService.subjectName(task.subject) === intent.subject &&
          ((index === snapshot.currentTaskIndex && (snapshot.isRunning || task.outcome === 'studying')) ||
            task.outcome === 'focused' || task.outcome === 'submitted'));
        if (protectedTask !== undefined) { next.preferredTaskId = protectedTask.id; }
        else {
          const blocked: boolean = (snapshot.tasks ?? []).some((task: StudyTask) => !task.completed &&
            TodayStudyOverrideService.subjectName(task.subject) === intent.subject &&
            ((next.skippedTaskIds ?? []).includes(task.id ?? '') || (snapshot.actionDeferrals ?? []).some(item =>
              item.key === `task:${task.id}` && item.until > now)));
          if (blocked) { return { kind: 'clarify', intent: intent,
            message: '这科已有任务今天被跳过或暂缓。请先在“调整今天安排”恢复它，我不会另外复制一项绕过你的选择。' }; }
          added = TodayIntentService.newTasks(snapshot, merged, strategy, now);
          next.temporaryTaskIds = (next.temporaryTaskIds ?? []).concat(added.map((task: StudyTask) => task.id ?? ''));
          next.preferredTaskId = added[0]?.id ?? '';
        }
      }
      merged.taskId = next.preferredTaskId || undefined;
    }
    PlanValidator.validateTodayCreation(snapshot, merged, added, next, now);
    StudyDecisionDebug.event('PARSED_INTENT', merged.taskId ?? '', merged.subject ?? '', '', merged.action);
    StudyDecisionDebug.event('NORMALIZED_SUBJECT', '', merged.subject ?? '');
    StudyDecisionDebug.event(added.length ? 'CREATED_TODAY_TASK' : 'MATCHED_EXISTING_TASK', next.preferredTaskId ?? '', merged.subject ?? '');
    StudyDecisionDebug.event('VALIDATOR_RESULT', next.preferredTaskId ?? '', '', '', 'accepted');
    return { kind: 'commit', intent: merged, override: next, createdTasks: added, message: '' };
  }

  static describe(snapshot: StudyStateSnapshot, now: number = Date.now()): string {
    const decision = AgentDecisionService.decide(snapshot, now);
    const action = decision.recommendedAction;
    const override: TodayStudyOverride | undefined = TodayStudyOverrideService.active(snapshot, now);
    const subject: string = override?.intent?.subject ?? '';
    const prefix: string = subject.length > 0 ? `好，今天优先学习${TodayStudyOverrideService.subjectName(subject)}。` : '';
    if (action.stage === 'resume' || action.stage === 'verify') {
      return `${prefix}请先${action.stage === 'resume' ? '继续正在进行的专注' : '完成待提交的反馈'}「${action.headline}」。新意图将在当前状态结束后生效。`;
    }
    if (decision.dailyPlan.length === 0) {
      if (subject.length > 0 && LearningActionService.candidates(snapshot, now).length === 0) {
        const finished: boolean = snapshot.tasks.some((task: StudyTask) => task.completed &&
          TodayStudyOverrideService.subjectName(task.subject) === TodayStudyOverrideService.subjectName(subject));
        return finished ? `这轮${subject}已经完成。要继续${subject}还是换一科？我先保留你的选择，不会自动换科。` :
          `目前没有可执行的${subject}学习任务。可以告诉我想复习什么，我会帮你安排；今日已跳过的任务不会自动恢复。`;
      }
      return `${prefix}${action.headline}。${action.reason}`;
    }
    const lines: string[] = decision.dailyPlan.map((item, index: number) =>
      `${index + 1}. ${item.title} · ${TodayStudyOverrideService.subjectName(item.subject)} · ${item.suggestedMinutes}分钟`);
    const unknown: string = override?.availableMinutes === undefined ?
      '\n尚未确认今天剩余时间，先展示当前这一项；告诉我还能学多久，就能继续安排后续任务。' : '';
    return `${prefix}今天按这个节奏：\n${lines.join('\n')}\n先从「${action.headline}」开始。${unknown}`;
  }

  private static explain(snapshot: StudyStateSnapshot, now: number): string {
    const decision = AgentDecisionService.decide(snapshot, now);
    const action = decision.recommendedAction;
    const reason = decision.reasonChain[0];
    if (action.taskId === undefined) {
      return `当前还没有可以解释的具体学习行动。${action.headline}。${action.reason}`;
    }
    if (reason === undefined) {
      return `当前先安排「${action.headline}」，因为${action.reason}。这次说明不会修改你的任务或今日安排。`;
    }
    return `我这样安排，是因为${reason.data}；${reason.judgment}。所以现在建议先做「${action.headline}」${
      action.minutes > 0 ? `，约${action.minutes}分钟` : ''}。这次说明不会修改你的任务或今日安排。`;
  }

  private static reminder(snapshot: StudyStateSnapshot, subject: string | undefined, now: number): string {
    const goals: AcademicGoal[] = GoalPlanningService.activeGoals(snapshot.academicGoals ?? [], now)
      .filter((goal: AcademicGoal) => !subject || TodayStudyOverrideService.subjectName(goal.subject) === subject);
    if (goals.length === 0) { return '目前没有对应的有效日期提醒，可以到“学习目标”查看或添加。今天的学习安排没有改变。'; }
    return goals.map((goal: AcademicGoal) => {
      const days: number = GoalPlanningService.daysUntil(goal.deadline, now);
      return `${goal.title}：${goal.deadline}，${days === 0 ? '今天截止' : `还有${days}天`}。`;
    }).join('\n') + '\n这是日期提醒，不会自动改变今天的安排。';
  }
}
