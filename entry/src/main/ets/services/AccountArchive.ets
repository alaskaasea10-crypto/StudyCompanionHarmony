import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AccountSession } from './AccountSession';

export class AccountArchive {
  static async exists(context: common.UIAbilityContext, owner: string): Promise<boolean> {
    const store = await preferences.getPreferences(context, AccountSession.storeName('account_archive', owner));
    return await store.get('ready', false) === true;
  }
  static async prepare(context: common.UIAbilityContext, owner: string, copyGuest: boolean): Promise<void> {
    if (owner.length === 0) { throw new Error('目标必须为账号档案'); }
    if (await AccountArchive.exists(context, owner)) { return; }
    // Marker is committed LAST. Interrupted first-time copies can safely be retried;
    // a previously initialized account is never overwritten by guest data.
    const names: string[] = ['learner_profile', 'matrix_question_bank_v1', 'learning_video_library'];
    for (const base of names) {
      const source = await preferences.getPreferences(context, base);
      const target = await preferences.getPreferences(context, AccountSession.storeName(base, owner));
      const key: string = base === 'learner_profile' ? 'study_state_v1' : 'records';
      const fallback: string = base === 'learner_profile' ? '' : base === 'matrix_question_bank_v1' ?
        '{"version":1,"sessions":[]}' : '{"favoriteIds":[],"watchedIds":[]}';
      const raw: string = copyGuest ? await source.get(key, fallback) as string : fallback;
      await target.put(key, raw);
      await target.flush();
    }
    const marker = await preferences.getPreferences(context, AccountSession.storeName('account_archive', owner));
    await marker.put('ready', true);
    try { await marker.flush(); } catch (error) {
      await marker.put('ready', false);
      throw new Error('账号档案保存失败，请重试');
    }
  }
}
