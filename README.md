# 学伴·星球 StudyCompanionHarmony

面向大学生日常学习场景的 HarmonyOS Learning Agent，通过课表、任务、可用时间、Focus 和学习反馈，帮助用户判断当前应该优先完成什么任务。

## Overview

学习信息经常分散在课表、待办和专注工具中，用户仍需手动判断下一步行动。学伴·星球将 App 内已确认的学习上下文连接起来，让建议、执行、反馈与重新规划形成连续流程。

## Core Flow

```text
Learning Context
→ Agent Proposal
→ Server / Client Validation
→ User Confirmation
→ Today Plan
→ Focus
→ Feedback
→ Re-plan
```

- 复杂、多科、时间权衡与解释型请求由 openPangu 辅助结构化理解并提出建议。
- 明确、低歧义指令由客户端确定性逻辑处理。
- 模型建议不会直接修改真实任务、Focus 或学习结果。

## Tech Stack

- HarmonyOS / ArkTS / ArkUI
- Python standard-library backend
- openPangu
- Hvigor / ohpm

## Project Structure

```text
AppScope/   App-level configuration and resources
entry/      HarmonyOS client, models, services and UI
backend/    Agent API, validation and read-only tools
scripts/    Regression and static verification scripts
docs/       Architecture, handoff and acceptance notes
```

## Quick Start

1. Open the repository root in DevEco Studio; do not open only `entry/`.
2. Install the SDK versions requested by the project and wait for ohpm/Hvigor sync.
3. Configure your own local debug signing in DevEco Studio.
4. Select the `entry` module and run it on a supported phone or tablet target.

Target SDK: `6.1.1(24)`

Compatible SDK: `5.0.0(12)`

Detailed setup, backend and review instructions: [FINAL_SOURCE_README.md](FINAL_SOURCE_README.md)

Backend tests:

```bash
python3 -m unittest discover -s backend/tests -v
```

## Agent Safety Boundary

- Proposal does not equal execution.
- Plans are checked by server-side constraints and client validators.
- User confirmation controls persistence for conversational proposals.
- The model cannot arbitrarily delete or complete tasks, write the repository, or modify `FocusRecord`.
- Cloud failure falls back to the existing local decision path instead of blocking the core learning flow.

## Current Scope

The core Phone flow—Today Plan, Small Planet conversation, Focus, Feedback and Re-plan—is implemented. Tablet configuration, Service Card and Xiaoyi entry points exist, while some capabilities still require validation on corresponding devices, system versions or permission environments. Cross-device real-time synchronization is not claimed as complete.

## Local Backend

The App is configured to use the project cloud backend by default. Local backend execution is optional for development. Copy `backend/.env.example` to `backend/.env` and provide your own credentials locally; never commit `.env`, API keys or signing files. See [backend/README.md](backend/README.md).

## Security

This repository must not contain private signing material, API keys, tokens, server credentials, competition registration forms or personal contact information.
