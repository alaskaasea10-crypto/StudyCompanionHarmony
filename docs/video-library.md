# 知识补给：首版范围与核验

入口：专注 → 成长与小队 → 校园与职业助手 → 四个模块。

目录在 `entry/src/main/ets/services/VideoCatalog.ets`，每条含原平台 URL、来源、主题、日期（未知则留空）、内容类型和提示。扩充后共 21 条：职业规划6条，租房避坑5条，医保报销5条，合同检查5条。页面/搜索索引核对日期 2026-09-08；不等于完整视频播放、专业质量或现行政策有效性验证。B站链接可能需要登录或受到访问限制。

内容来源：
- 中国大学MOOC：https://www.icourse163.org/course/detail.htm?cid=408003
- B站简历专题：https://www.bilibili.com/video/BV1NL4y1878J/
- B站投递渠道：https://www.bilibili.com/video/BV1k44y1u78g/
- 央视租赁条例：https://tv.cctv.com/2025/09/15/VIDEUqNr0xu0IcXi1jL13f2J250915.shtml
- 央视房源核查：https://tv.cctv.com/2025/07/22/VIDEdhURWuKZGQN57Of9Tu6j250722.shtml
- 国家医保局短片（湖北转载）：https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250910_5768602.shtml
- 国家医保局备案动画：https://www.nhsa.gov.cn/art/2023/6/1/art_171_10727.html
- 人社部合同条款：https://www.mohrss.gov.cn/xxgk2020/fdzdgknr/zcjd/zcjdwz/202112/t20211207_429736.html
- 央视试用期案例：https://v.cctv.com/2023/06/20/VIDEsCgDoIo3W6DR8y6LXJbS230620.shtml

## 第二批新增来源（12项）

- 就业指导：职业选择与求职准备：https://jc.mohrss.gov.cn/lesson/817
- 求职能力实训：表达、简历与面试：https://jc.mohrss.gov.cn/lesson/1177
- 大学生就业指南（1—41讲）：https://jc.mohrss.gov.cn/lesson/476
- 房东能随意扣减租房押金吗？：https://tv.cctv.com/2025/07/22/VIDE6ZPYnJVmaQRoeMdmmZLJ250722.shtml
- 租住期间：安全合理使用住房：https://tv.cctv.com/2025/07/22/VIDEiqxKETOJhbxfBTEsB5mV250722.shtml
- 城市如何对青年更友好？：https://tv.cctv.com/2025/05/14/VIDEWK9bxzVwqr18PNaZOAho250514.shtml
- 异地就医直接结算：住院跨省结算篇：https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250911_5769565.shtml
- 异地就医直接结算：普通门诊跨省结算篇：https://ybj.hubei.gov.cn/wxjz/spxw/202509/t20250912_5770632.shtml
- 戏说医保：异地就医知识：https://www.nhsa.gov.cn/art/2023/6/1/art_171_10723.html
- 关于劳动合同，你要知道的那些事儿：https://jc.mohrss.gov.cn/lesson/230
- 劳动关系管理：订立、履行与变更：https://jc.mohrss.gov.cn/lesson/891
- 财经调查：手机租赁藏消费陷阱：https://tv.cctv.com/2025/04/13/VIDEGgdmkJBSFoFdL3oJ6X1r250413.shtml

新增就创平台课程已核对搜索索引中的课程简介；直接页面依赖动态加载，尚未逐课登录验证。其余新增项目根据原站视频简介收录，不声明具体视频时长，不将来源平台等同于个性化专业意见。

## 实现

- 分类、关键词、全部/收藏/已看筛选；空结果可重置。
- 收藏、手动已看可撤销；独立 Preferences `learning_video_library`，不修改学习掌握度。
- 只允许目录来源的 HTTPS 链接；交由系统 openLink 打开原平台，失败有提示。
- 不读取或声称外站观看进度；不复制、下载、内嵌第三方视频或封面。
- 加入现有任务列表，确定性 ID 防重复，预留15分钟观看与笔记，不伪造视频时长。
- 视频任务的专注页可返回对应视频；结束计时不触发无关学科测验。提供复制原始链接的备用入口。
- B站扩展搜索仅传模块通用关键词，不上传用户画像、合同、病历或测验记录。

## 尚未实现

自动知识点匹配、视频专属测验、实际播放进度、云同步、动态更新目录，以及医保/合同的个性化办理或审核。添加新条目时应检查来源、发布时间和适用范围，不把历史报道当现行办事指南。

## 验证

`scripts/test-video-catalog.cjs` 使用 DevEco 的 TypeScript 转译纯目录逻辑，检查分类、筛选、记录去重与恢复、非法输入、URL 白名单。页面需另外构建 HAP 并在设备上验证。

2026-09-08：HAP 编译通过；模拟器验证职业规划入口、收藏与已看记录保存/恢复/撤销、空状态筛选，已清除测试标记。外跳能唤起系统浏览器，但MOOC页面在模拟器中显示空白，未验证完整视频播放。独立测试使用 Index 的实际任务方法验证添加、防重复、保存失败回滚，以及视频任务不触发学科测验；不写入真实用户任务。
