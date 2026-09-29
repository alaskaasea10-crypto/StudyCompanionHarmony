import { http } from '@kit.NetworkKit';
import { SmallPlanetReplyRequest, SmallPlanetReplyResponse } from '../models/AgentModels';
import { BackendConfig } from './BackendConfig';

export class SmallPlanetClient {
  static async reply(payload: SmallPlanetReplyRequest): Promise<SmallPlanetReplyResponse> {
    const origins: string[] = BackendConfig.origins();
    let lastError: string = '暂时无法连接小星球';
    for (let index: number = 0; index < origins.length; index += 1) {
      const request: http.HttpRequest = http.createHttp();
      try {
        const response: http.HttpResponse = await request.request(
          `${origins[index]}/api/agent/small-planet-reply`, {
            method: http.RequestMethod.POST,
            header: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
            extraData: JSON.stringify(payload), expectDataType: http.HttpDataType.STRING,
            connectTimeout: 6000, readTimeout: 35000, usingCache: false
          });
        const raw: string = response.result as string;
        if (raw.trim().length === 0) { throw new Error('小星球服务没有返回内容'); }
        const result: SmallPlanetReplyResponse = JSON.parse(raw) as SmallPlanetReplyResponse;
        if (response.responseCode < 200 || response.responseCode >= 300 || !result.ok ||
          result.reply === undefined || result.reply.trim().length === 0) {
          throw new Error(result.error ?? `小星球服务暂不可用（${response.responseCode}）`);
        }
        return result;
      } catch (error) {
        const current: string = error instanceof Error ? error.message : '暂时无法连接小星球';
        lastError = current.includes('[object Object]') ? '暂时无法连接小星球' : current;
      } finally { request.destroy(); }
    }
    throw new Error(lastError);
  }
}
