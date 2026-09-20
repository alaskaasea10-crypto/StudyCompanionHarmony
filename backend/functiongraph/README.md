# FunctionGraph 部署包

这一目录把现有学伴后端适配为华为云 FunctionGraph 事件函数。它不会读取或打包
`backend/.env`，API Key必须在FunctionGraph控制台通过环境变量配置。

## 当前云端能力

- `GET /health`：部署与密钥配置检查；
- `POST /api/agent/today-plan`：调用openPangu生成结构化今日计划；
- `POST /api/agent/emotional-support`：调用openPangu生成学习情绪陪伴回复；
- `POST /api/schedule/parse`：解析HarmonyOS Core Vision返回的文字行；
- 不在云端接收整张课表图片，避免上传敏感图片和引入Mac专用Vision依赖。

## 生成部署包

在项目根目录运行：

```bash
python3 backend/functiongraph/build_package.py
```

输出文件为：

```text
backend/dist/functiongraph-agent.zip
```

压缩包不包含API Key。可用以下命令检查：

```bash
unzip -l backend/dist/functiongraph-agent.zip
```

## 控制台参数（上传前复核）

- 函数类型：事件函数；
- 运行时：Python 3.12；
- 处理器：`index.handler`；
- 函数访问公网：开启（用于访问ModelArts MaaS）；
- 环境变量：`OPENPANGU_API_KEY`、`OPENPANGU_API_URL`、`OPENPANGU_MODEL`；
- 内存与超时：先使用256MB、40秒测试；
- HTTPS触发器：优先选择控制台可用的共享/免费API入口；若页面要求购买专享APIG，先停止并核对费用。

建议为 `GET /health`、`POST /api/agent/today-plan`、
`POST /api/agent/emotional-support` 和 `POST /api/schedule/parse` 分别配置路径，均指向同一函数。赛事测试阶段可暂用无认证
入口，但必须增加随机请求令牌或网关限流后再长期公开。
