import { StudyStateSnapshot } from '../models/StudyModels';
import { TodayStudyOverrideService } from './TodayStudyOverrideService';

export interface SmallPlanetRouteDecision {
  path: string;
  deterministicEligible: boolean;
  deterministicConfidence: string;
  semanticRoute: string;
  subjects: string[];
  timeBudgetMinutes?: number;
}

// 这里只批准语义单一的命令进入确定性执行；其余表达交给 Pangu 理解，默认不修改状态。
export class SmallPlanetConversationRouter {
  static decide(text: string, _snapshot: StudyStateSnapshot, hasPendingProposal: boolean): SmallPlanetRouteDecision {
    const message: string = text.trim();
    const subjects: string[] = TodayStudyOverrideService.subjectsIn(message);
    const budgetMatch: RegExpMatchArray | null = message.match(/(?:只有|剩|还能|就剩)?\s*(\d{1,3})\s*分钟/);
    const hourMatch: RegExpMatchArray | null = message.match(/(?:只有|剩|还能|就剩)?\s*([1-5一二两三四五])\s*(?:个)?小时/);
    const digitHour: number = hourMatch === null ? 0 : Number(hourMatch[1]);
    const chineseHours: string[] = ['一', '二', '三', '四', '五'];
    const hour: number = digitHour > 0 ? digitHour : hourMatch === null ? 0 : chineseHours.indexOf(hourMatch[1]) + 1;
    const minutes: number | undefined = budgetMatch !== null ? Number(budgetMatch[1]) : hour > 0 ? hour * 60 : undefined;
    if (hasPendingProposal && /^(?:(?:行|好|可以)[，,]\s*)?(?:确认|就这样|就按你说的(?:来|安排)?|按这个方案|行|好|可以)(?:吧)?[。！!\s]*$/.test(message)) {
      return { path: 'confirm-proposal', deterministicEligible: true, deterministicConfidence: 'high',
        semanticRoute: 'confirmation', subjects: subjects, timeBudgetMinutes: minutes };
    }
    if (/^(?:返回上一步|撤销|撤回上一步|撤销上一步)[。！!\s]*$/.test(message)) {
      return { path: 'deterministic', deterministicEligible: true, deterministicConfidence: 'high',
        semanticRoute: 'undo', subjects: subjects, timeBudgetMinutes: minutes };
    }
    const questionOrAdvice: boolean = /[？?]|(?:为什么|为何|怎么|如何|你觉得|你建议|应该|合理|怎么办|哪个|哪一个|分配|权衡|看不懂|不理解)/.test(message);
    const mixedOrEmotional: boolean = /(?:但是|不过|可是|同时|也|都|又|还要|不想|不愿|焦虑|烦|累|压力|来不及)/.test(message);
    const directAction: boolean = /(?:学|复习|预习|练习|做题|背单词)/.test(message);
    const oneSubject: boolean = subjects.length === 1;
    const compact: boolean = message.length <= 28 && (message.match(/[，,；;]/g) ?? []).length <= 1;
    if (oneSubject && (directAction || minutes !== undefined) && compact && !questionOrAdvice && !mixedOrEmotional) {
      return { path: 'deterministic', deterministicEligible: true, deterministicConfidence: 'high',
        semanticRoute: 'single-action', subjects: subjects, timeBudgetMinutes: minutes };
    }
    const budgetOnly: boolean = subjects.length === 0 && minutes !== undefined &&
      /^(?:今天|今晚|现在)?(?:只有|剩|还能|就剩)?\s*(?:\d{1,3}\s*分钟|[1-5一二两三四五]\s*(?:个)?小时)[了。！!\s]*$/.test(message);
    if (budgetOnly) {
      return { path: 'deterministic', deterministicEligible: true, deterministicConfidence: 'high',
        semanticRoute: 'budget-only', subjects: subjects, timeBudgetMinutes: minutes };
    }
    return { path: 'semantic', deterministicEligible: false, deterministicConfidence: 'insufficient',
      semanticRoute: subjects.length > 1 ? 'multi-goal-advice' : questionOrAdvice ? 'advice-or-explanation' :
        mixedOrEmotional ? 'mixed-context' : 'ambiguous', subjects: subjects, timeBudgetMinutes: minutes };
  }
}
