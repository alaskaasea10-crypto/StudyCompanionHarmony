# 学伴·星球 StudyCompanionHarmony

## 评审运行说明 / Quick Start

本说明用于快速打开、构建并验证比赛源码。项目的核心链路是：Agent 理解学习需求 → 用户确认建议 → Today Plan → Focus → Feedback → Re-plan。

## 1. 最快体验方式

### 1.1 打开工程

1. 解压源码包。
2. 解压后，请使用 DevEco Studio 打开 `StudyCompanionHarmony/` 根目录，不要只打开 `entry/`。
3. 正确的工程根目录包含：
   - `AppScope/`
   - `entry/`
   - `backend/`
   - `scripts/`
   - `build-profile.json5`
   - `hvigorfile.ts`
   - `oh-package.json5`

### 1.2 同步依赖

- 打开工程后等待或执行项目同步，并按 DevEco Studio 提示安装 oh-package 依赖。
- 本工程配置为 Target HarmonyOS SDK `6.1.1(24)`、Compatible HarmonyOS SDK `5.0.0(12)`；缺少 SDK 时请按提示安装对应版本。
- 推荐使用与工程模型版本一致的 DevEco Studio `6.1.1`。

### 1.3 配置本机签名

提交包不包含私人签名密钥、证书密码或 keystore。其他电脑首次构建时，请在 DevEco Studio 中为本机重新配置调试签名或自动签名；不要复制原开发者的签名材料。

### 1.4 Build / Run

1. 选择 `entry` 模块并完成项目同步。
2. 选择可用的 HarmonyOS Phone/Tablet 模拟器或已授权真机。
3. 执行 Build 或 Run；真机运行需要设备连接和本机签名环境正常。
4. DevEco Studio 可按当前工程配置生成 HAP。

### 1.5 核心 Agent 快速体验

推荐评审路径：

1. 启动 App，完成首次学习画像。
2. 确认 App 中至少有一项高等数学未完成任务、一项线性代数未完成任务，并将今天可用时间设为 60 分钟。
3. 在首页打开“小星球”，输入：

   > 我今晚只有一个小时，高数快考试了，但线代也落下不少，你觉得我应该怎么分配？为什么？

4. 查看 openPangu 对复杂多科需求给出的结构化建议。此时建议不会直接修改 Today Plan。
5. 输入：

   > 行，就按你说的来

6. 返回首页查看确认后写入的真实 Today Plan。
7. 从当前任务进入 Focus；结束本轮后选择学习体验并完成产出自查，再返回首页观察 Re-plan 后的下一步行动。

复杂表达由 openPangu 辅助理解并提出建议；模型建议先经过服务端和客户端校验，只有用户明确确认后，才允许写入今天的真实安排。后续 Focus、Feedback 与 Re-plan 始终基于真实任务状态运行。

## 2. 推荐测试数据

为了完整体验多学科建议，建议通过 App 内现有界面准备：

- 1 个高等数学未完成任务；
- 1 个线性代数未完成任务；
- 1 个高等数学长期目标或考试日期（可选，仅作为建议背景）；
- 当天可用时间 60 分钟。

新安装首次完成学习画像后，当前实现会按所选科目生成一组入门学习任务；这些任务只属于所选科目。若要体验多学科场景，请继续通过 App 内的真实任务/今日安排入口准备另一科任务，不需要编辑数据库、JSON 或 Repository。内置演示课表在用户确认前不会作为真实 Today Plan 依据。

## 3. 云端 Agent 说明

- HarmonyOS 客户端通过项目 backend 访问 openPangu。
- 当前客户端默认配置连接项目云端服务；体验 App 时通常不需要在电脑上启动本地 Python backend。
- Small Planet 的复杂语义理解和自然语言建议需要网络。
- 云端不可用时，部分明确指令与本地确定性学习安排仍可工作，但不等同于完整的 openPangu 建议能力。
- 源码和本说明不包含 API Key、Token、服务器账号或部署密钥。

## 4. Backend 本地运行

本地 backend 是可选的开发/复现方式。当前 Python 服务使用标准库，没有额外的 `requirements.txt` 依赖。

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
cp .env.example .env
```

在本机 `.env` 中自行填写所需环境变量，至少需要有效的 `OPENPANGU_API_KEY` 才能调用 openPangu；不要提交或分享 `.env`。

启动命令：

```bash
python3 app.py
```

本地健康检查默认为 `http://127.0.0.1:8000/health`。只有开发者主动清空客户端的云端 Backend Origin 时，模拟器才会回退访问宿主机本地服务；评委只体验默认 App 时无需运行本地 backend。

`backend/.env.example` 仅列出当前代码实际读取的变量：

- `OPENPANGU_API_KEY`
- `OPENPANGU_API_URL`
- `OPENPANGU_MODEL`
- `AGENT_BACKEND_HOST`
- `AGENT_BACKEND_PORT`

Linux 部署还可通过 `AGENT_RUNTIME_NAME` 覆盖健康检查中的运行环境标签；本地运行无需设置。

## 5. 项目结构

- `AppScope/`：HarmonyOS 应用级配置与资源。
- `entry/`：ArkTS / ArkUI 客户端、页面、服务、模型与资源。
- `backend/`：Python Agent API、openPangu 调用、只读 Tool 与课表解析服务。
- `scripts/`：项目回归测试和静态验证脚本。
- `docs/`：设计、验收与技术说明。
- `hvigor/`、`build-profile.json5`、`hvigorfile.ts`：HarmonyOS 构建配置。

## 6. Agent 执行边界

- 复杂、多目标或解释型请求：openPangu 进行结构化理解并提出 proposal。
- 明确且低歧义的指令：客户端本地确定性逻辑处理。
- 模型不能任意创建、删除或完成真实任务，不能直接写 Repository，也不能直接修改 FocusRecord。
- 真实执行必须经过服务端约束、客户端校验（`SmallPlanetSemanticValidator` / `PlanValidator`）和用户确认。
- 用户确认控制最终持久化；模型建议本身不等于执行结果。

## 7. 建议验证功能

1. 首页“现在”推荐；
2. Small Planet 复杂多科问题；
3. Advice ≠ Execution；
4. 用户确认后 Today Plan 更新；
5. Focus；
6. Feedback；
7. Re-plan；
8. Live View（真机与系统版本支持时）。

## 8. 当前能力说明

本项目本次主要验证链路为：

Agent → Today Plan → Focus → Feedback → Re-plan

以下能力已有代码实现或工程配置，但不作为本次核心复现路径：

- 课表导入 / OCR；
- Tablet 支持配置；
- Service Card；
- 小艺页面入口。

其中部分能力仍需要在对应设备、系统版本或权限环境下进一步验收。

跨设备实时同步目前不作为已完成能力，也不属于本次核心验证范围。

建议评审优先验证 Phone 端的 Agent、Today Plan、Focus、Feedback、Re-plan 与 Live View 主流程。

## 9. Security / Secrets

提交源码包不包含：

- `.env`；
- 真实 API Key 或 Token；
- 私人签名材料与密码；
- SSH 私钥；
- 生产账号或密码。

其他开发者需要自行配置本机 DevEco Studio 签名；如选择运行本地 backend，还需要自行提供 `backend/.env` 所需环境变量。请始终保留 `backend/.env.example` 作为无密钥模板，不要将本机 `.env` 或签名文件加入版本控制或提交包。
