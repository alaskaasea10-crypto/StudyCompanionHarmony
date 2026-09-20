import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { http } from '@kit.NetworkKit';
import { ScheduleApiResponse, ScheduleImportResult, ScheduleOcrLine } from '../models/ScheduleImportModels';
import { BackendConfig } from './BackendConfig';

const CORE_VISION_TIMEOUT_MS: number = 3500;

export class ScheduleImportClient {
  static async selectAndRecognize(): Promise<ScheduleImportResult> {
    const uri: string = await ScheduleImportClient.selectImage();
    return await ScheduleImportClient.recognizeUri(uri);
  }

  static async recognizeUri(uri: string): Promise<ScheduleImportResult> {
    const bytes: Uint8Array = ScheduleImportClient.readImage(uri);
    console.info(`ScheduleImport: selected image (${bytes.byteLength} bytes)`);
    try {
      const lines: ScheduleOcrLine[] = await ScheduleImportClient.withTimeout(
        ScheduleImportClient.recognizeWithCoreVision(bytes),
        CORE_VISION_TIMEOUT_MS,
        '当前设备暂不支持端侧文字识别'
      );
      if (lines.length > 0) {
        console.info(`ScheduleImport: Core Vision recognized ${lines.length} lines`);
        return await ScheduleImportClient.requestSchedule('/api/schedule/parse', JSON.stringify({ lines: lines }));
      }
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      console.info(`ScheduleImport: Core Vision unavailable, using local fallback (${message})`);
    }
    console.info('ScheduleImport: sending image to the local OCR fallback');
    const base64: string = new util.Base64Helper().encodeToStringSync(bytes);
    return await ScheduleImportClient.requestSchedule(
      '/api/schedule/ocr',
      JSON.stringify({ imageBase64: base64 })
    );
  }

  private static withTimeout<T>(promise: Promise<T>, timeoutMs: number, message: string): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason?: Error) => void) => {
      const timer: number = setTimeout(() => {
        reject(new Error(message));
      }, timeoutMs);
      promise.then((value: T) => {
        clearTimeout(timer);
        resolve(value);
      }).catch((error: Error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  private static async selectImage(): Promise<string> {
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    try {
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        throw new Error('没有选择课表图片');
      }
      return result.photoUris[0];
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (message.includes('取消') || message.includes('没有选择') || message.includes('cancel')) {
        throw new Error('没有选择课表图片');
      }
      throw new Error('无法打开相册，请稍后重试');
    }
  }

  private static readImage(uri: string): Uint8Array {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0 || size > 8 * 1024 * 1024) {
        throw new Error('请选择小于 8MB 的课表截图');
      }
      const buffer: ArrayBuffer = new ArrayBuffer(size);
      const readSize: number = fileIo.readSync(file.fd, buffer);
      if (readSize <= 0) {
        throw new Error('无法读取所选课表图片');
      }
      return new Uint8Array(buffer, 0, readSize);
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (message.includes('8MB') || message.includes('无法读取')) {
        throw new Error(message);
      }
      throw new Error('无法读取所选课表图片，请重新选择');
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          console.error(`ScheduleImport: failed to close selected image: ${error}`);
        }
      }
    }
  }

  private static async recognizeWithCoreVision(bytes: Uint8Array): Promise<ScheduleOcrLine[]> {
    const source: image.ImageSource = image.createImageSource(bytes.buffer as ArrayBuffer);
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      pixelMap = await source.createPixelMap();
      const imageInfo: image.ImageInfo = await pixelMap.getImageInfo();
      const imageWidth: number = Math.max(1, imageInfo.size.width);
      const imageHeight: number = Math.max(1, imageInfo.size.height);
      const initialized: boolean = await textRecognition.init();
      if (!initialized) {
        throw new Error('Core Vision OCR 初始化失败');
      }
      let result: textRecognition.TextRecognitionResult;
      try {
        result = await textRecognition.recognizeText({
          pixelMap: pixelMap
        });
      } catch (error) {
        throw new Error('Core Vision OCR 识别失败');
      }
      const lines: ScheduleOcrLine[] = [];
      for (const block of result.blocks) {
        for (const line of block.lines) {
          if (line.cornerPoints.length === 0 || line.value.trim().length === 0) {
            continue;
          }
          let minX: number = line.cornerPoints[0].x;
          let maxX: number = minX;
          let minY: number = line.cornerPoints[0].y;
          let maxY: number = minY;
          for (const point of line.cornerPoints) {
            minX = Math.min(minX, point.x);
            maxX = Math.max(maxX, point.x);
            minY = Math.min(minY, point.y);
            maxY = Math.max(maxY, point.y);
          }
          lines.push({
            text: line.value,
            x: minX / imageWidth,
            y: minY / imageHeight,
            width: (maxX - minX) / imageWidth,
            height: (maxY - minY) / imageHeight
          });
        }
      }
      return lines;
    } finally {
      try {
        await textRecognition.release();
      } catch (error) {
      }
      if (pixelMap !== undefined) {
        await pixelMap.release();
      }
      await source.release();
    }
  }

  private static async requestSchedule(path: string, body: string): Promise<ScheduleImportResult> {
    const request: http.HttpRequest = http.createHttp();
    let responseReceived: boolean = false;
    try {
      const response: http.HttpResponse = await request.request(`${BackendConfig.origin()}${path}`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 6000,
        readTimeout: 50000,
        usingCache: false
      });
      responseReceived = true;
      const raw: string = response.result as string;
      if (raw.trim().length === 0) {
        throw new Error('课表识别服务没有返回内容');
      }
      let payload: ScheduleApiResponse;
      try {
        payload = JSON.parse(raw) as ScheduleApiResponse;
      } catch (error) {
        throw new Error('课表识别服务返回格式异常，请重试');
      }
      if (response.responseCode < 200 || response.responseCode >= 300 || !payload.ok || payload.scheduleItems === undefined) {
        throw new Error(payload.error ?? `课表识别服务暂不可用（${response.responseCode}）`);
      }
      if (payload.scheduleItems.length === 0) {
        throw new Error('没有识别出课程，请换一张完整清晰的课表截图');
      }
      return {
        source: payload.source ?? 'ocr',
        scheduleItems: payload.scheduleItems
      };
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (!responseReceived) {
        throw new Error(BackendConfig.isLocal() ?
          '无法连接课表识别服务。请先启动电脑端 backend/app.py，再重新选择图片。' :
          '暂时无法连接云端课表解析服务，请稍后重试。');
      }
      throw new Error(message.length > 0 ? message : '课表识别失败');
    } finally {
      request.destroy();
    }
  }
}
