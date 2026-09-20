import { LearningVideo, VideoModule, VideoLibraryState } from '../models/VideoModels';

// 人工核对来源页面的首批目录。仅外链，不复制或托管第三方视频。
// 页面核对日期：2026-09-08；播放、登录、收费条件以原平台为准。
const MODULES: VideoModule[] = [
  { id: 'matrix', title: '矩阵乘法补学', subtitle: '从计算规则到变换的直觉', accent: '#596EA7', tint: '#EDF1FA', searchTerm: '矩阵乘法 行乘列 线性变换 结合律' },
  { id: 'career', title: '职业规划', subtitle: '从认识自己，到准备下一步', accent: '#5567A3', tint: '#EDF0FA', searchTerm: '大学生 职业规划 简历 面试' },
  { id: 'housing', title: '租房避坑', subtitle: '为第一次独立生活做好准备', accent: '#9B704C', tint: '#F8EFE7', searchTerm: '央视 租房 避坑 押金' },
  { id: 'insurance', title: '医保报销', subtitle: '了解基本流程，办事少些困惑', accent: '#427E70', tint: '#EAF4EF', searchTerm: '国家医保局 异地就医 备案' },
  { id: 'contract', title: '合同检查', subtitle: '先补充知识，再核实具体条款', accent: '#80649B', tint: '#F2ECF7', searchTerm: '人力资源社会保障部 劳动合同 必备条款' }
];

const VIDEOS: LearningVideo[] = [
  { id: 'matrix-composition', moduleId: 'matrix', title: '线性代数的本质：矩阵乘法与线性变换复合', topic: '运算顺序', platform: '哔哩哔哩', publisher: '原视频发布者（见平台）', url: 'https://www.bilibili.com/video/BV1ms41167u9/', publishedAt: '', format: '直观讲解', description: '从线性变换的复合理解矩阵乘法，补充为什么顺序不能随意交换的直觉。', note: '已核对搜索索引；原站限制自动读取，未验证完整播放。可能需登录，以平台为准。' },
  { id: 'matrix-course', moduleId: 'matrix', title: '线性代数：矩阵代数与乘法基础', topic: '乘法基础', platform: '中国大学MOOC', publisher: '四川大学', url: 'https://www.icourse163.org/learn/SCU-1462906163', publishedAt: '', format: '学校课程', description: '系统补充矩阵的运算与线性变换知识，可寻找对应章节复习乘法条件和计算。', note: '页面标注 SPOC 学校专有课程，可能限制选课或要求学校账号；无法访问时可使用自己的教材或课堂笔记。' },
  {"id":"career-employment","moduleId":"career","title":"就业指导：职业选择与求职准备","topic":"就业准备","platform":"人社就创平台","publisher":"就业创业和职业培训在线服务平台","url":"https://jc.mohrss.gov.cn/lesson/817","publishedAt":"","format":"系统课程","description":"结合自身特点选择职业，学习简历、面试与笔试的准备方法。","note":"平台收录课程；可能需要登录或报名，授课信息及费用以课程页为准。"},
  {"id":"career-practice","moduleId":"career","title":"求职能力实训：表达、简历与面试","topic":"求职实训","platform":"人社就创平台","publisher":"求职能力实训学员班课程","url":"https://jc.mohrss.gov.cn/lesson/1177","publishedAt":"","format":"实训课程","description":"按需选择职场表达、制作简历及面试训练等章节。","note":"课程含多个训练单元；可自行选学，不代表看完即可获得就业资格。"},
  {"id":"career-graduate","moduleId":"career","title":"大学生就业指南（1—41讲）","topic":"毕业准备","platform":"人社就创平台","publisher":"就业创业和职业培训在线服务平台","url":"https://jc.mohrss.gov.cn/lesson/476","publishedAt":"","format":"系列课程","description":"从求职准备到面试类型，按章节补充毕业求职所需知识。","note":"可能需要登录；招聘流程与信息请结合当年实际情况核对。"},
  {"id":"housing-deposit","moduleId":"housing","title":"房东能随意扣减租房押金吗？","topic":"押金问题","platform":"央视网","publisher":"CCTV-13 · 东方时空","url":"https://tv.cctv.com/2025/07/22/VIDE6ZPYnJVmaQRoeMdmmZLJ250722.shtml","publishedAt":"2025-07-22","format":"新闻短片","description":"围绕押金扣减问题，了解签约与退租时值得关注的约定。","note":"历史新闻解读；具体纠纷需结合合同、证据及现行规定判断。"},
  {"id":"housing-safety","moduleId":"housing","title":"租住期间：安全合理使用住房","topic":"租住安全","platform":"央视网","publisher":"CCTV-13 · 东方时空","url":"https://tv.cctv.com/2025/07/22/VIDEiqxKETOJhbxfBTEsB5mV250722.shtml","publishedAt":"2025-07-22","format":"新闻短片","description":"认识承租人在使用住房时需要注意的安全与责任问题。","note":"2025年报道；实际租住要求以现行规定及合法合同约定为准。"},
  {"id":"housing-youth","moduleId":"housing","title":"城市如何对青年更友好？","topic":"青年安居","platform":"央视网","publisher":"CCTV-13 · 新闻1+1","url":"https://tv.cctv.com/2025/05/14/VIDEWK9bxzVwqr18PNaZOAho250514.shtml","publishedAt":"2025-05-14","format":"新闻解读","description":"了解青年社区与保租房等安居话题，拓宽毕业后的住房选择思路。","note":"报道中的项目和申请资格不一定适用于你所在城市，请向当地核实。"},
  {"id":"insurance-inpatient","moduleId":"insurance","title":"异地就医直接结算：住院跨省结算篇","topic":"住院结算","platform":"湖北省医保局","publisher":"国家医保局（湖北省医保局转载）","url":"https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250911_5769565.shtml","publishedAt":"2025-09-11","format":"官方短片","description":"了解跨省住院结算的基础知识，为办理前咨询做好准备。","note":"须结合参保地、险种和当前经办要求核实，不据此计算个人报销金额。"},
  {"id":"insurance-outpatient","moduleId":"insurance","title":"异地就医直接结算：普通门诊跨省结算篇","topic":"门诊结算","platform":"湖北省医保局","publisher":"国家医保局（湖北省医保局转载）","url":"https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250912_5770632.shtml","publishedAt":"2025-09-12","format":"官方短片","description":"补充普通门诊跨省结算与相关办理问题的知识。","note":"全国性科普；实际待遇和可用医院应向参保地医保部门核对。"},
  {"id":"insurance-opera","moduleId":"insurance","title":"戏说医保：异地就医知识","topic":"趣味科普","platform":"国家医保局","publisher":"浙江省苍南县医保局 · 宣传作品展播","url":"https://www.nhsa.gov.cn/art/2023/6/1/art_171_10723.html","publishedAt":"2023-06-01","format":"科普短片","description":"用戏曲形式了解异地就医注意事项及结算相关常识。","note":"2023年宣传作品，部分政策或操作流程可能变化；以最新官方指南为准。"},
  {"id":"contract-course","moduleId":"contract","title":"关于劳动合同，你要知道的那些事儿","topic":"合同入门","platform":"人社就创平台","publisher":"就业创业和职业培训在线服务平台","url":"https://jc.mohrss.gov.cn/lesson/230","publishedAt":"","format":"系统课程","description":"学习合同订立、劳动报酬、休息休假及争议解决等基础内容。","note":"平台收录课程；可能需要登录或报名，不替代专业法律意见。"},
  {"id":"contract-relations","moduleId":"contract","title":"劳动关系管理：订立、履行与变更","topic":"劳动关系","platform":"人社就创平台","publisher":"就业创业和职业培训在线服务平台","url":"https://jc.mohrss.gov.cn/lesson/891","publishedAt":"","format":"进阶课程","description":"适合想进一步了解劳动关系、合同履行和劳动保障监察的用户。","note":"偏管理视角的系统课程，按需选择；课程规则以平台为准。"},
  {"id":"contract-consumer","moduleId":"contract","title":"财经调查：手机租赁藏消费陷阱","topic":"消费合同","platform":"央视网","publisher":"CCTV-2 · 财经调查","url":"https://tv.cctv.com/2025/04/13/VIDEGgdmkJBSFoFdL3oJ6X1r250413.shtml","publishedAt":"2025-04-13","format":"案例节目","description":"通过手机租赁案例，关注消费协议中的费用及个人信息问题。","note":"案例报道仅供风险教育，不据此判断某一平台或合同的合法性。"},
  { id: 'career-course', moduleId: 'career', title: '职业生涯规划：自我探索与行动路线', topic: '方向探索', platform: '中国大学MOOC', publisher: '《职业生涯规划》课程', url: 'https://www.icourse163.org/course/detail.htm?cid=408003', publishedAt: '', format: '系统课程', description: '从兴趣、能力与职业环境出发，梳理自己的发展方向。', note: '可能需要登录、选课；开课安排以平台为准。' },
  { id: 'career-resume', moduleId: 'career', title: '简历制作技巧与案例分析', topic: '简历准备', platform: '哔哩哔哩', publisher: '框框的B站大学 · 简历攻略', url: 'https://www.bilibili.com/video/BV1NL4y1878J/', publishedAt: '', format: '视频专题', description: '自主选择简历写法、案例和常见问题等内容。', note: '个人创作者内容；已核对搜索索引，播放可用性以平台为准。' },
  { id: 'career-channels', moduleId: 'career', title: '大学生职业规划：简历投递的平台与渠道', topic: '求职渠道', platform: '哔哩哔哩', publisher: '原视频发布者（见平台）', url: 'https://www.bilibili.com/video/BV1k44y1u78g/', publishedAt: '', format: '视频讲解', description: '了解求职信息渠道，为自己的下一次投递做准备。', note: '较早发布的内容；招聘渠道与规则请核对现状。' },
  { id: 'housing-rules', moduleId: 'housing', title: '租房新规来了：住房租赁条例', topic: '租赁常识', platform: '央视网', publisher: 'CCTV-2 · 正点财经', url: 'https://tv.cctv.com/2025/09/15/VIDEUqNr0xu0IcXi1jL13f2J250915.shtml', publishedAt: '2025-09-15', format: '新闻短片', description: '了解住房租赁规则的背景，建立签约前的核查意识。', note: '历史政策报道，仅作知识补充；具体事项核对现行规定。' },
  { id: 'housing-quality', moduleId: 'housing', title: '租房避坑：关注串串房与隔断房', topic: '房源核查', platform: '央视网', publisher: 'CCTV-13 · 共同关注', url: 'https://tv.cctv.com/2025/07/22/VIDEdhURWuKZGQN57Of9Tu6j250722.shtml', publishedAt: '2025-07-22', format: '新闻短片', description: '了解房源质量与租住安全问题，看房时更有准备。', note: '视频为当时的新闻解读，不构成对具体房源的判断。' },
  { id: 'insurance-filing', moduleId: 'insurance', title: '异地就医直接结算：备案篇', topic: '异地备案', platform: '湖北省医保局', publisher: '国家医保局（湖北省医保局转载）', url: 'https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250910_5768602.shtml', publishedAt: '2025-09-10', format: '官方短片', description: '了解异地就医备案的基本问题与办理思路。', note: '全国性知识介绍；参保地、险种及最新经办要求须另行核实。' },
  { id: 'insurance-guide', moduleId: 'insurance', title: '跨省异地就医备案攻略', topic: '办理渠道', platform: '国家医保局', publisher: '国家医保局 · 宣传作品展播', url: 'https://www.nhsa.gov.cn/art/2023/6/1/art_171_10727.html', publishedAt: '2023-06-01', format: '官方动画', description: '通过动画了解备案渠道与操作流程。', note: '2023年宣传内容，操作界面可能已变；以参保地当前指南为准。' },
  { id: 'contract-terms', moduleId: 'contract', title: '劳动合同必备条款有哪些？', topic: '签约基础', platform: '人社部', publisher: '人力资源和社会保障部', url: 'https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcjd/zcjdwz/202112/t20211207_429736.html', publishedAt: '2021-12-07', format: '官方视频', description: '签约前认识合同结构，准备需要向用人单位确认的问题。', note: '较早的普法内容；不能替代现行规定核对或专业法律意见。' },
  { id: 'contract-probation', moduleId: 'contract', title: '案例学习：两年半还在试用期？', topic: '试用期', platform: '央视网', publisher: '央视网 · 法院案例报道', url: 'https://v.cctv.com/2023/06/20/VIDEsCgDoIo3W6DR8y6LXJbS230620.shtml', publishedAt: '2023-06-20', format: '案例短片', description: '通过一个试用期纠纷案例，建立核查合同约定的意识。', note: '个案不代表所有情形；不据此自动判断你的合同是否合法。' }
];

export class VideoCatalog {
  static modules(): VideoModule[] { return MODULES; }
  static all(): LearningVideo[] { return VIDEOS; }
  static module(id: string): VideoModule { return MODULES.find((item: VideoModule) => item.id === id) ?? MODULES[1]; }
  static topics(moduleId: string): string[] {
    const topics: string[] = ['全部'];
    VIDEOS.filter((item: LearningVideo) => item.moduleId === moduleId).forEach((item: LearningVideo) => {
      if (!topics.includes(item.topic)) { topics.push(item.topic); }
    });
    return topics;
  }
  static filter(moduleId: string, topic: string, query: string, mode: string, favorites: string[], watched: string[]): LearningVideo[] {
    const keyword: string = query.trim().toLowerCase();
    return VIDEOS.filter((item: LearningVideo) => item.moduleId === moduleId &&
      (topic === '全部' || item.topic === topic) &&
      (keyword.length === 0 || `${item.title} ${item.topic} ${item.description} ${item.platform}`.toLowerCase().includes(keyword)) &&
      (mode !== '收藏' || favorites.includes(item.id)) && (mode !== '已看' || watched.includes(item.id)));
  }
  static toggle(ids: string[], id: string): string[] {
    if (!VIDEOS.some((item: LearningVideo) => item.id === id)) { return ids; }
    return ids.includes(id) ? ids.filter((value: string) => value !== id) : ids.concat([id]);
  }
  static normalizeIds(value: string[]): string[] {
    if (!Array.isArray(value)) { return []; }
    return VIDEOS.filter((item: LearningVideo) => value.includes(item.id)).map((item: LearningVideo) => item.id);
  }
  static decode(raw: string): VideoLibraryState {
    const value: VideoLibraryState = JSON.parse(raw) as VideoLibraryState;
    return { favoriteIds: VideoCatalog.normalizeIds(value?.favoriteIds), watchedIds: VideoCatalog.normalizeIds(value?.watchedIds) };
  }
  static allowedUrl(url: string): boolean {
    return /^https:\/\/(www\.bilibili\.com|search\.bilibili\.com|www\.icourse163\.org|tv\.cctv\.com|v\.cctv\.com|www\.nhsa\.gov\.cn|ybj\.hubei\.gov\.cn|www\.mohrss\.gov\.cn|jc\.mohrss\.gov\.cn)\//.test(url);
  }
}
