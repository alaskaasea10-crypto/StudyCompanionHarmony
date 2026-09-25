# 学伴 Agent 服务

这个服务承担三项工作：通过 openPangu Native Function Calling 为真实任务生成今日安排、提供学习情绪陪伴，以及把课表 OCR 结果解析成统一课程数据。生产 App 默认访问 `https://api.badminton2026.site`；开发时 API Key 只保存在本机 `backend/.env`，云端部署时只保存在服务器环境变量，始终不会进入 ArkTS 源码。

今日计划链路为：客户端提交最小请求 → openPangu 按需调用四个只读 Tool → Tool Registry 从本次客户端可信上下文返回结果 → openPangu 规划 → 服务端 `validate_plan` → 客户端 `PlanValidator`。云端不是用户任务数据库；客户端本地仍是学习状态的主要来源，云端失败时 App 会回退到本地调度。

课表识别没有使用小艺：

- HarmonyOS 真机优先调用 Core Vision Kit 识别文字和坐标，再由本服务解析课表结构；
- 模拟器无法使用 Core Vision 时，本服务调用 macOS Vision 作为开发备用识别；
- 两条路径都要经过 App 内的预览确认，确认后才写入首页推荐、Agent 规划和课表页共用的数据中心。

## 首次配置

```bash
cd StudyCompanionHarmony/backend
cp .env.example .env
```

然后打开 `.env`，只填写：

```text
OPENPANGU_API_KEY=你的API Key
```

若华为云控制台显示的接口地址或模型名不同，同时修改 `.env` 中对应配置。

## 可选的本地开发启动

```bash
cd StudyCompanionHarmony/backend
python3 app.py
```

本地开发期间不要关闭这个终端。浏览器访问 `http://127.0.0.1:8000/health`，看到 `"ok": true` 且 `"configured": true` 即配置成功。

只有开发者主动清空 App 的云端 Backend Origin 时，DevEco 模拟器才会通过 `10.0.2.2:8000` 访问宿主 Mac。正式版本不依赖该地址，也不要求 Mac 运行 `backend/app.py`。

## 课表导入

在首次学习画像或“学习 → 课表与计划”中点击“导入截图/重新识别”，选择一张同时包含星期栏、上课时间、课程名与地点的完整截图。在系统相册预览页还需点击右下角“完成”，图片才会交给 App。识别成功后先核对预览，再点“确认导入”。

接口：

- `POST /api/schedule/parse`：解析 Core Vision 返回的文字行和坐标；
- `POST /api/schedule/ocr`：模拟器把图片发到本机 macOS Vision 识别并解析。
- `POST /api/agent/emotional-support`：生成克制、可执行的学习情绪陪伴回复。

## 可选的 FunctionGraph 部署准备

当前项目已经提供FunctionGraph事件函数入口。先生成不含密钥的部署包：

```bash
cd StudyCompanionHarmony
python3 backend/functiongraph/build_package.py
unzip -l backend/dist/functiongraph-agent.zip
```

部署包入口为 `index.handler`，支持健康检查、openPangu今日计划、情绪陪伴和端侧OCR文字解析。
详细控制台参数见 `backend/functiongraph/README.md`。

如另行使用 FunctionGraph 获得 HTTPS 调用地址，只需修改：

```text
entry/src/main/ets/services/BackendConfig.ets
```

将 `CLOUD_BACKEND_ORIGIN` 填为不带末尾斜杠的 HTTPS 根地址。当前比赛生产地址已经配置；不要把 API Key 放进应用。

## 测试

```bash
cd StudyCompanionHarmony
python3 -m unittest discover -s backend/tests -v
```
