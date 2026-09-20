# 学伴 Agent 服务

这个服务承担三项工作：调用华为云 openPangu 生成今日任务、提供学习情绪陪伴，以及把课表 OCR 结果解析成统一课程数据。开发时API Key只保存在本机 `backend/.env`；云端部署时只保存在FunctionGraph环境变量，始终不会进入ArkTS源码。

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

## 启动

```bash
cd StudyCompanionHarmony/backend
python3 app.py
```

识别课表或生成 Agent 计划期间不要关闭这个终端。浏览器访问 `http://127.0.0.1:8000/health`，看到 `"ok": true` 且 `"configured": true` 即配置成功。

DevEco 模拟器会通过 `10.0.2.2:8000` 访问宿主 Mac，因此服务默认监听 `0.0.0.0`，不需要额外做 `hdc rport` 端口映射。若手动把 `AGENT_BACKEND_HOST` 改回 `127.0.0.1`，模拟器将无法连接并会退回本地方案。

## 课表导入

在首次学习画像或“学习 → 课表与计划”中点击“导入截图/重新识别”，选择一张同时包含星期栏、上课时间、课程名与地点的完整截图。在系统相册预览页还需点击右下角“完成”，图片才会交给 App。识别成功后先核对预览，再点“确认导入”。

接口：

- `POST /api/schedule/parse`：解析 Core Vision 返回的文字行和坐标；
- `POST /api/schedule/ocr`：模拟器把图片发到本机 macOS Vision 识别并解析。
- `POST /api/agent/emotional-support`：生成克制、可执行的学习情绪陪伴回复。

## FunctionGraph部署准备

当前项目已经提供FunctionGraph事件函数入口。先生成不含密钥的部署包：

```bash
cd StudyCompanionHarmony
python3 backend/functiongraph/build_package.py
unzip -l backend/dist/functiongraph-agent.zip
```

部署包入口为 `index.handler`，支持健康检查、openPangu今日计划、情绪陪伴和端侧OCR文字解析。
详细控制台参数见 `backend/functiongraph/README.md`。

FunctionGraph获得HTTPS调用地址后，只需修改：

```text
entry/src/main/ets/services/BackendConfig.ets
```

将 `CLOUD_BACKEND_ORIGIN` 填为不带末尾斜杠的HTTPS根地址。留空时App继续使用
`http://127.0.0.1:8000`，所以本地开发方式不会被破坏。不要把API Key放进应用。

## 测试

```bash
cd StudyCompanionHarmony
python3 -m unittest discover -s backend/tests -v
```
