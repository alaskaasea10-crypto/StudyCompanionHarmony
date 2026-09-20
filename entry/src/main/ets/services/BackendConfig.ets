// 云端部署完成后，只需要填写这一处HTTPS地址，不要在App中填写API Key。
// 示例：https://example.apig.cn-north-4.huaweicloudapis.com
const CLOUD_BACKEND_ORIGIN: string = '';
// DevEco 模拟器通过 10.0.2.2 访问宿主 Mac；127.0.0.1 在模拟器内指向模拟器自身。
const EMULATOR_BACKEND_ORIGIN: string = 'http://10.0.2.2:8000';
// 真机调试时，手机与 Mac 连接同一 Wi-Fi 后通过 Mac 的局域网地址访问本地服务。
const LAN_BACKEND_ORIGIN: string = 'http://192.168.1.103:8000';
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
    // 同时兼容 DevEco 模拟器、HarmonyOS 真机和同机预览器。
    return [EMULATOR_BACKEND_ORIGIN, LAN_BACKEND_ORIGIN, LOCAL_BACKEND_ORIGIN];
  }

  static isLocal(): boolean {
    return BackendConfig.normalize(CLOUD_BACKEND_ORIGIN).length === 0;
  }

  static healthEndpoint(): string {
    return `${BackendConfig.origin()}/health`;
  }
}
