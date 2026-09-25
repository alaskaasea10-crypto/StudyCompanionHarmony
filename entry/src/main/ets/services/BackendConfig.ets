// 云端部署完成后，只需要填写这一处HTTPS地址，不要在App中填写API Key。
// 示例：https://example.apig.cn-north-4.huaweicloudapis.com
const CLOUD_BACKEND_ORIGIN: string = 'https://api.badminton2026.site';
// DevEco 模拟器通过 10.0.2.2 访问宿主 Mac；127.0.0.1 在模拟器内指向模拟器自身。
const EMULATOR_BACKEND_ORIGIN: string = 'http://10.0.2.2:8000';
const LOCAL_BACKEND_ORIGIN: string = 'http://127.0.0.1:8000';

export class BackendConfig {
  private static normalize(origin: string): string {
    const value: string = origin.trim();
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static origin(): string {
    return BackendConfig.origins()[0];
  }

  static origins(): string[] {
    const cloudOrigin: string = BackendConfig.normalize(CLOUD_BACKEND_ORIGIN);
    if (cloudOrigin.length > 0) {
      return [cloudOrigin];
    }
    // 云端地址被开发者主动留空时，仅回退到模拟器宿主和同机预览器。
    return [EMULATOR_BACKEND_ORIGIN, LOCAL_BACKEND_ORIGIN];
  }

  static isLocal(): boolean {
    return BackendConfig.normalize(CLOUD_BACKEND_ORIGIN).length === 0;
  }

  static healthEndpoint(): string {
    return `${BackendConfig.origin()}/health`;
  }
}
