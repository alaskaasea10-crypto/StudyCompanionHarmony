import {
  DocType,
  DocumentScanner,
  DocumentScannerConfig,
  EditTab,
  FilterId,
  SaveOption,
  ShootingMode
} from '@kit.VisionKit';

@Component
export struct ScheduleScannerPageView {
  onScanned: (uri: string) => void = () => {};
  onCancel: () => void = () => {};

  private scannerConfig: DocumentScannerConfig = {
    maxShotCount: 1,
    supportType: [DocType.SHEET],
    isGallerySupported: true,
    defaultFilterId: FilterId.STRENGTHEN,
    editTabs: [EditTab.ROTATE_TAB, EditTab.RESHOOT_TAB],
    defaultShootingMode: ShootingMode.AUTO,
    isShareable: false,
    saveOptions: [SaveOption.JPG]
  };

  build() {
    DocumentScanner({
      scannerConfig: this.scannerConfig,
      onResult: (_code: number, saveType: SaveOption, uris: string[]) => {
        if (saveType === SaveOption.JPG && uris.length > 0) {
          this.onScanned(uris[0]);
          return;
        }
        this.onCancel();
      }
    })
      .width('100%')
      .height('100%')
  }
}
