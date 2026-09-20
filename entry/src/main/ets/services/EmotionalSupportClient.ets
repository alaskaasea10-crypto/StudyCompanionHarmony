import { http } from '@kit.NetworkKit';
import {
  EmotionalSupportMessage,
  EmotionalSupportRequest,
  EmotionalSupportResponse
} from '../models/EmotionalSupportModels';
import { BackendConfig } from './BackendConfig';

export class EmotionalSupportClient {
  static crisisText(): string {
    return '我很在意你现在的安全。请先不要独处，马上联系一位你信任的人陪着你；如果你可能立即伤害自己，请拨打 120 或 110，或直接前往最近的急诊。此刻先把可能伤害自己的物品放远一点。';
  }

  static isCrisis(text: string): boolean {
    return /自杀|自残|伤害自己|不想活|活不下去|结束生命|去死/.test(text);
  }

  static async reply(message: string, history: EmotionalSupportMessage[]): Promise<EmotionalSupportResponse> {
    const clean: string = message.trim();
    if (EmotionalSupportClient.isCrisis(clean)) {
      return { ok: true, reply: EmotionalSupportClient.crisisText(), crisis: true, source: 'safety-policy' };
    }
    const payload: EmotionalSupportRequest = { message: clean, history: history.slice(-8) };
    const origins: string[] = BackendConfig.origins();
    let lastError: string = '暂时无法连接星球';
    for (let index: number = 0; index < origins.length; index += 1) {
      const request: http.HttpRequest = http.createHttp();
      try {
        const response: http.HttpResponse = await request.request(
          `${origins[index]}/api/agent/emotional-support`, {
            method: http.RequestMethod.POST,
            header: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            extraData: JSON.stringify(payload),
            expectDataType: http.HttpDataType.STRING,
            connectTimeout: 6000,
            readTimeout: 35000,
            usingCache: false
          });
        const raw: string = response.result as string;
        if (raw.trim().length === 0) {
          throw new Error('星球服务没有返回内容');
        }
        const result: EmotionalSupportResponse = JSON.parse(raw) as EmotionalSupportResponse;
        if (response.responseCode < 200 || response.responseCode >= 300 || !result.ok || result.reply === undefined) {
          throw new Error(result.error ?? `星球服务暂不可用（${response.responseCode}）`);
        }
        return result;
      } catch (error) {
        const current: string = error instanceof Error ? error.message : '暂时无法连接星球';
        lastError = current.includes('[object Object]') ? '暂时无法连接星球' : current;
      } finally {
        request.destroy();
      }
    }
    throw new Error(`${lastError}（已尝试模拟器、真机局域网与本机服务）`);
  }
}
