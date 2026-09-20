# 学伴·星球团队接手说明

## 1. 本地代码

收到 `StudyCompanionHarmony-team-*.zip` 后，先解压，再用 DevEco Studio 的 **Open Project** 打开解压得到的 `StudyCompanionHarmony` 文件夹（不要只打开 `entry`）。等待依赖同步完成，选择 `entry` 和模拟器/真机运行。开发环境建议与项目一致：DevEco Studio 项目模型 `6.1.1`，HarmonyOS SDK target `6.1.1(24)`、compatible `5.0.0(12)`。

首次运行时，每位成员都需要在 **File → Project Structure → Signing Configs** 创建自己的调试签名；团队包中的 `build-profile.json5` 已移除创建者电脑上的证书路径和口令。`local.properties` 也不会随包发送，由 DevEco Studio 在朋友电脑上生成。

如果依赖同步异常，优先在 DevEco Studio 中执行项目同步，不要互相复制 `.hvigor`、`oh_modules` 或 `entry/build`。

## 2. Agent 与课表后端

本地后端配置文件为 `backend/.env`，它不会进入 Git 或团队压缩包。复制 `backend/.env.example` 后，成员自行填写可使用的盘古 API Key。

只想先看界面和离线功能，可以不启动后端；要测试小星球的盘古回复或课表识别，朋友需在自己电脑的 `backend` 目录运行 `python3 app.py`，再访问 `http://127.0.0.1:8000/health` 检查。模拟器访问电脑后端用 `10.0.2.2:8000`；真机需与电脑处于同一 Wi-Fi，并把 `entry/src/main/ets/services/BackendConfig.ets` 中的 `LAN_BACKEND_ORIGIN` 改成朋友电脑的局域网 IP。代码包里当前的局域网 IP 是创建者电脑的，朋友不能直接沿用。

主要接口：

- `GET /health`：检查服务及模型配置；
- `POST /api/agent/today-plan`：生成精简的今日学习计划；
- `POST /api/agent/emotional-support`：学习压力与情绪陪伴；
- `POST /api/schedule/parse`：解析端侧 OCR 文字与坐标；
- `POST /api/schedule/ocr`：仅用于 macOS 本地模拟器的 Vision 备用识别。

FunctionGraph 部署说明见 `backend/functiongraph/README.md`。云端 API Key 只能放在 FunctionGraph 环境变量中，不能写入 ArkTS、提交记录或群聊。

## 3. 小艺意图配置

代码中的五条端侧 Deeplink 意图为：

| 意图英文名 | 用户能力 | Deeplink |
| --- | --- | --- |
| `OpenNextStudyAction` | 查看现在该学什么 | `studycompanion://action/next` |
| `OpenFocusSpace` | 开始或继续专注 | `studycompanion://action/focus` |
| `OpenTodaySchedule` | 查看今日课表 | `studycompanion://action/schedule` |
| `OpenLearningCenter` | 打开学习中心 | `studycompanion://action/learning` |
| `OpenEmotionalSupport` | 打开情绪陪伴 | `studycompanion://action/support` |

小艺开放平台上的意图集属于华为开发者账号，不随 Git 仓库复制。需要共同管理时，应通过华为开发者团队权限邀请成员，不要共享主账号密码。

真机端到端验证需要 HarmonyOS 6.0.0(20)+ 设备、最新版小艺，以及已加入平台测试用户组的华为账号。

## 4. 当前产品主链路

首页只给出一个优先行动：课程/计划/薄弱点等信息先进入统一决策，再跳转专注或对应学习入口。结束计时只代表投入时间；任务提交、练习反馈与掌握验证分别记录，避免把“学过”误判为“学会”。

## 5. 协作约定

- 功能分支小步提交，提交信息写清用户可见结果；
- 不提交密钥、签名文件、个人路径和真实用户数据；
- 修改首页或学习页时，优先维持“一个明确下一步”，避免重新堆叠文本卡片；
- 修改计划、任务或反馈模型时，同时检查首页、学习页、专注页、提醒和桌面卡片是否仍指向同一行动。
