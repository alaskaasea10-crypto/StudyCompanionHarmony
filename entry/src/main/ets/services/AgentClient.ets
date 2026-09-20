import { http } from '@kit.NetworkKit';
import { AgentApiResponse, AgentPlan, AgentPlanRequest } from '../models/AgentModels';
import { BackendConfig } from './BackendConfig';

// 本地开发会依次尝试 DevEco 模拟器宿主网关和 localhost。
// 正式部署地址统一在 BackendConfig 中配置，API Key 始终留在服务端。

interface AgentErrorLike {
  message?: string;
}

export class AgentClient {
  private static readableError(error: Object): string {
    if (error instanceof Error && error.message.trim().length > 0) {
      return error.message.trim();
    }
    const errorLike: AgentErrorLike = error as AgentErrorLike;
    if (errorLike.message !== undefined && errorLike.message.trim().length > 0 &&
      errorLike.message !== '[object Object]') {
      return errorLike.message.trim();
    }
    return '无法连接 Agent 服务';
  }

  static async generateTodayPlan(requestData: AgentPlanRequest): Promise<AgentPlan> {
    const origins: string[] = BackendConfig.origins();
    let lastError: string = '无法连接 Agent 服务';
    for (let index: number = 0; index < origins.length; index += 1) {
      const request: http.HttpRequest = http.createHttp();
      try {
        const response: http.HttpResponse = await request.request(
          `${origins[index]}/api/agent/today-plan`, {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            extraData: JSON.stringify(requestData),
            expectDataType: http.HttpDataType.STRING,
            connectTimeout: 6000,
            readTimeout: 35000,
            usingCache: false
          });
        const raw: string = response.result as string;
        if (raw.trim().length === 0) {
          throw new Error('Agent 服务没有返回内容');
        }
        let payload: AgentApiResponse;
        try {
          payload = JSON.parse(raw) as AgentApiResponse;
        } catch (error) {
          throw new Error('Agent 服务返回格式异常，请稍后重试');
        }
        if (response.responseCode < 200 || response.responseCode >= 300 || !payload.ok || payload.plan === undefined) {
          throw new Error(payload.error ?? `Agent 服务暂不可用（${response.responseCode}）`);
        }
        return payload.plan;
      } catch (error) {
        lastError = AgentClient.readableError(error as Object);
      } finally {
        request.destroy();
      }
    }
    throw new Error(`${lastError}（已尝试模拟器、真机局域网与本机服务）`);
  }
}
