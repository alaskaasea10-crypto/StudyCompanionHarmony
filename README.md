# 学伴·星球（StudyCompanionHarmony）

面向大学生的 HarmonyOS 学习陪伴应用。产品以“现在该学什么”为主线，把课程、目标、专注、学习反馈和情绪陪伴收敛到一个清晰的下一步行动。

## 当前能力

- 首页统一展示今日行动、当前目标、课程提示与连续学习状态；
- 学习中心支持目标规划、学习资料和盘古 Agent 对话；
- 专注计时、Live View、桌面卡片和共学光场联动；
- 星球角色会随连续学习成长，并承担低打扰提醒；
- Core Vision 课表图片识别与导入确认；
- openPangu 今日计划与情绪陪伴后端；
- 小艺 Intents Kit 页面直达：下一步、专注、课表、学习中心、情绪陪伴。

## 开发环境

- DevEco Studio，项目模型版本 `6.1.1`；
- HarmonyOS SDK：target `6.1.1(24)`，compatible `5.0.0(12)`；
- Python 3.10+（本地 Agent 后端和测试）。

## 打开和运行

1. 使用 DevEco Studio 打开本目录。
2. 等待 ohpm/Hvigor 同步依赖。
3. 在 **File > Project Structure > Signing Configs** 中配置自己的调试签名。
4. 选择手机或平板设备，运行 `entry`。

团队交付压缩包不包含任何人的证书、签名口令、API Key 或本地 SDK 路径；不要直接打包开发电脑上的整个工作目录发送。

## Agent 架构与可选本地后端

正式版本默认访问 `https://api.badminton2026.site`。学习状态仍以 App 本地数据为准：

`HarmonyOS App → 本地 AgentDecisionService → LearningPlanningOrchestrator → HTTPS 云端 Agent → openPangu Native Tool Loop → 服务端校验 → 客户端 PlanValidator`

云端只对本次请求中由客户端提交的真实课表、目标、任务和专注记录执行受控只读查询，不是用户任务数据库。云端不可用时，App 会使用本地可信调度继续工作。主动提醒也只在系统实际允许的生命周期内运行，不代表 App 被彻底杀死后仍能全天候推理。

仅在开发调试云端不可用的版本时，才需要启动本地后端：

```bash
cd backend
cp .env.example .env
# 只在本机 backend/.env 中填写 OPENPANGU_API_KEY
python3 app.py
```

当 `BackendConfig` 中的云端地址被开发者主动留空时，模拟器可通过 `10.0.2.2:8000` 连接开发机后端。生产默认不依赖 Mac 运行 Python。完整说明见 [backend/README.md](backend/README.md)。

## 验证

```bash
python3 -m unittest discover -s backend/tests -v
```

HarmonyOS HAP 构建可在 DevEco Studio 中执行，或使用本机 DevEco 自带的 Hvigor。

## 团队协作

请先阅读 [docs/team-handoff.md](docs/team-handoff.md)。不要提交 `backend/.env`、`local.properties` 或 DevEco 自动生成的本机签名材料。
