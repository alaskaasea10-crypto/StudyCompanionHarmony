import { formatSubjectName } from '../utils/SubjectDisplayName';

export type LearningResourceType = 'video' | 'exercise';

export interface LearningResourceSearchRequest {
  subject: string;
  taskTitle: string;
  resourceType: LearningResourceType;
}

export interface LearningResourceSearchResult {
  displayQuery: string;
  externalUri: string;
  provider: string;
}

// 只把当前真实任务转换为外部搜索意图；不读取、创建或保存任何学习任务。
export class LearningResourceSearchService {
  private static cleanTaskTitle(value: string, subject: string): string {
    let title: string = formatSubjectName(value).replace(/[\r\n\t]+/g, ' ').replace(/\s+/g, ' ').trim();
    title = title.replace(/^(请|现在|今天)?\s*(学习|复习|巩固|练习|完成|整理|掌握|攻克|回顾|确认)\s*/,
      '').replace(/^[：:、，,\-—·\s]+/, '').trim();
    if (title.startsWith(subject)) {
      title = title.substring(subject.length).replace(/^[：:、，,\-—·\s]+/, '').trim();
    }
    return title;
  }

  static searchLearningResources(request: LearningResourceSearchRequest): LearningResourceSearchResult | undefined {
    const subject: string = formatSubjectName(request.subject).trim();
    if (subject.length === 0 || request.taskTitle.trim().length === 0) { return undefined; }
    const topic: string = LearningResourceSearchService.cleanTaskTitle(request.taskTitle, subject);
    if (topic.length === 0) { return undefined; }
    const intent: string = request.resourceType === 'video' ? '讲解 教程' : '例题 解题';
    const displayQuery: string = `${subject} ${topic} ${intent}`;
    return {
      displayQuery: displayQuery,
      externalUri: `https://search.bilibili.com/all?keyword=${encodeURIComponent(displayQuery)}`,
      provider: '哔哩哔哩'
    };
  }
}

export function searchLearningResources(
  request: LearningResourceSearchRequest): LearningResourceSearchResult | undefined {
  return LearningResourceSearchService.searchLearningResources(request);
}
