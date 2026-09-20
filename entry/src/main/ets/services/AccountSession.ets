import { common } from '@kit.AbilityKit';
import { authentication } from '@kit.AccountKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

// Only a freshly returned native Account Kit credential can select an account namespace.
// Tokens and raw OpenID are never persisted, logged, or sent to the learning API.
export class AccountSession {
  private static scope: string = '';
  private static revision: number = 0;
  static owner(): string { return AccountSession.scope; }
  static generation(): number { return AccountSession.revision; }
  static select(owner: string): void {
    if (owner.length > 0 && !/^[a-f0-9]{64}$/.test(owner)) { throw new Error('无效的账号档案'); }
    AccountSession.scope = owner;
    AccountSession.revision++;
  }
  static storeName(base: string, owner: string = AccountSession.scope): string {
    return owner.length === 0 ? base : `${base}_${owner}`;
  }
  private static hex(bytes: Uint8Array): string {
    return Array.from(bytes).map((value: number) => value.toString(16).padStart(2, '0')).join('');
  }
  static async authorize(context: common.UIAbilityContext, interactive: boolean = true): Promise<string> {
    const state: string = AccountSession.hex(cryptoFramework.createRandom().generateRandomSync(32).data);
    const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
    const request: authentication.LoginWithHuaweiIDRequest = provider.createLoginWithHuaweiIDRequest();
    request.forceLogin = interactive;
    request.state = state;
    try {
      const controller: authentication.AuthenticationController = new authentication.AuthenticationController(context);
      const response: authentication.LoginWithHuaweiIDResponse =
        await controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;
      if (response.state !== state || response.data === undefined || response.data.openID.length === 0) {
        throw new Error('账号授权校验未通过');
      }
      const md: cryptoFramework.Md = cryptoFramework.createMd('SHA256');
      await md.update({ data: new util.TextEncoder().encodeInto(`huawei:${response.data.openID}`) });
      return AccountSession.hex((await md.digest()).data);
    } catch (error) {
      const code: number = (error as BusinessError).code ?? 0;
      throw new Error(`华为账号登录未完成（${code}）。如已取消可继续游客体验；否则请检查网络、系统账号及 APP ID 签名关联。`);
    }
  }
}
