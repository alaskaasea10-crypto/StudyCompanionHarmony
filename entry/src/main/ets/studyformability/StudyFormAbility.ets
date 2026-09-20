import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { StudyWidgetData, StudyWidgetService } from '../services/StudyWidgetService';

export default class StudyFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = `${want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? ''}`;
    StudyWidgetService.registerForm(this.context, formId)
      .then(() => StudyWidgetService.refreshForm(this.context, formId))
      .catch((error: Error) => {
        console.error(`StudyFormAbility: unable to initialize form: ${error.message}`);
      });
    return StudyWidgetService.bindingData(new StudyWidgetData());
  }

  onUpdateForm(formId: string): void {
    StudyWidgetService.refreshForm(this.context, formId).catch((error: Error) => {
      console.error(`StudyFormAbility: unable to update form: ${error.message}`);
    });
  }

  onRemoveForm(formId: string): void {
    StudyWidgetService.removeForm(this.context, formId).catch((error: Error) => {
      console.error(`StudyFormAbility: unable to remove form: ${error.message}`);
    });
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
