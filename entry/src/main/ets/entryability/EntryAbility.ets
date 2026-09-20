import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ActiveReminderService } from '../services/ActiveReminderService';
import { StudyActionRouter } from '../services/StudyActionRouter';
import '../services/StudyIntentLinks';

const DOMAIN = 0x0000;
const WIDGET_ROUTE_EVENT: string = 'studyWidgetRoute';

export default class EntryAbility extends UIAbility {
  private publishAppRoute(want: Want): void {
    const route: string = StudyActionRouter.fromWant(want);
    if (route.length === 0) { return; }
    AppStorage.setOrCreate<string>(WIDGET_ROUTE_EVENT, route);
    this.context.eventHub.emit(WIDGET_ROUTE_EVENT, route);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    this.publishAppRoute(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.publishAppRoute(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/AppRoot', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    ActiveReminderService.publishFromStoredState(this.context).catch((error: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to publish active reminder. Cause: %{public}s', error.message);
    });
  }
}
