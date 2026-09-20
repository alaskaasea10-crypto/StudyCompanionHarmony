import { InsightIntentLink } from '@kit.AbilityKit';

// 使用五个无参数 Link 意图，避免让小艺把“打开页面”误解成“任务已完成”。
@InsightIntentLink({
  intentName: 'OpenNextStudyAction',
  domain: 'Education',
  intentVersion: '1.0.0',
  displayName: '查看现在该学什么',
  llmDescription: '当用户问现在应该学什么、下一步做什么，或希望学伴给出唯一学习行动时使用。',
  uri: 'studycompanion://action/next'
})
export class NextStudyIntent {
}

@InsightIntentLink({
  intentName: 'OpenFocusSpace',
  domain: 'Education',
  intentVersion: '1.0.0',
  displayName: '开始或继续专注',
  llmDescription: '当用户明确希望开始学习、开始专注，或继续尚未结束的专注时使用。',
  uri: 'studycompanion://action/focus'
})
export class FocusStudyIntent {
}

@InsightIntentLink({
  intentName: 'OpenTodaySchedule',
  domain: 'Education',
  intentVersion: '1.0.0',
  displayName: '查看今日课表',
  llmDescription: '当用户想查看今天课程、上课时间或课表时使用，只打开课表，不替用户修改课程。',
  uri: 'studycompanion://action/schedule'
})
export class ScheduleStudyIntent {
}

@InsightIntentLink({
  intentName: 'OpenLearningCenter',
  domain: 'Education',
  intentVersion: '1.0.0',
  displayName: '打开学习中心',
  llmDescription: '当用户希望制定学习目标、调整计划或查找学习资料时使用。',
  uri: 'studycompanion://action/learning'
})
export class LearningCenterIntent {
}

@InsightIntentLink({
  intentName: 'OpenEmotionalSupport',
  domain: 'Education',
  intentVersion: '1.0.0',
  displayName: '打开情绪陪伴',
  llmDescription: '当用户表达学习焦虑、压力大、情绪低落或希望获得温和陪伴时使用。遇到危机内容时仍应优先建议寻求现实中的专业帮助。',
  uri: 'studycompanion://action/support'
})
export class EmotionalSupportIntent {
}
