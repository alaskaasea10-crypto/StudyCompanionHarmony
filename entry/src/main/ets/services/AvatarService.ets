import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

export class AvatarService {
  private static async selectImage(): Promise<string> {
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    try {
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        throw new Error('没有选择头像');
      }
      return result.photoUris[0];
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (message.includes('取消') || message.includes('没有选择') || message.includes('cancel')) {
        throw new Error('已取消选择头像');
      }
      throw new Error('无法打开图库，请稍后重试');
    }
  }

  private static removePreviousAvatar(previousUri: string): void {
    if (!previousUri.startsWith('file://')) {
      return;
    }
    try {
      fileIo.unlinkSync(previousUri.substring('file://'.length));
    } catch (error) {
      console.info(`AvatarService: previous avatar does not need cleanup: ${error}`);
    }
  }

  static async selectAndSave(context: common.UIAbilityContext, previousUri: string): Promise<string> {
    const sourceUri: string = await AvatarService.selectImage();
    let source: fileIo.File | undefined = undefined;
    try {
      source = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const size: number = fileIo.statSync(source.fd).size;
      if (size <= 0 || size > 10 * 1024 * 1024) {
        throw new Error('请选择小于10MB的头像图片');
      }
      const destination: string = `${context.filesDir}/profile_avatar_${Date.now()}`;
      fileIo.copyFileSync(source.fd, destination);
      // Guest-to-account copies may still reference the old immutable avatar file.
      // Keep it until an explicit archive deletion can determine all references.
      return `file://${destination}`;
    } catch (error) {
      const message: string = error instanceof Error ? error.message : `${error}`;
      if (message.includes('10MB')) {
        throw new Error(message);
      }
      throw new Error('头像保存失败，请重新选择');
    } finally {
      if (source !== undefined) {
        try {
          fileIo.closeSync(source);
        } catch (error) {
          console.error(`AvatarService: failed to close selected image: ${error}`);
        }
      }
    }
  }
}
