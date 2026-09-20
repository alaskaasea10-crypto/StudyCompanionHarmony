import { preferences } from '@kit.ArkData';
import { StudyStateSnapshot } from '../models/StudyModels';

const STATE_KEY: string = 'study_state_v1';

export class StudyRepository {
  private readonly store: preferences.Preferences;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  async load(): Promise<StudyStateSnapshot | undefined> {
    try {
      const raw: string = await this.store.get(STATE_KEY, '') as string;
      if (raw.length === 0) {
        return undefined;
      }
      const parsed: Object = JSON.parse(raw) as Object;
      if (parsed === null || Array.isArray(parsed)) {
        throw new Error('stored state is not an object');
      }
      return parsed as StudyStateSnapshot;
    } catch (error) {
      console.error(`StudyRepository: invalid stored state: ${error}`);
      return undefined;
    }
  }

  async save(snapshot: StudyStateSnapshot): Promise<void> {
    try {
      await this.store.put(STATE_KEY, JSON.stringify(snapshot));
      await this.store.flush();
    } catch (error) {
      console.error(`StudyRepository: failed to save state: ${error}`);
    }
  }

  // 用于需要向用户确认成功的操作；保留旧 save 的兼容行为。
  async saveChecked(snapshot: StudyStateSnapshot): Promise<void> {
    let previous: string = '';
    try { previous = await this.store.get(STATE_KEY, '') as string; } catch (error) {
      throw new Error('无法读取原记录，已取消保存');
    }
    try {
      await this.store.put(STATE_KEY, JSON.stringify(snapshot));
      await this.store.flush();
    } catch (error) {
      try { await this.store.put(STATE_KEY, previous); await this.store.flush(); } catch (rollbackError) {
        throw new Error('保存失败且磁盘回退未确认，请检查存储空间后重试');
      }
      throw new Error('保存失败，已恢复原记录');
    }
  }

  async clear(): Promise<void> {
    try {
      await this.store.delete(STATE_KEY);
      await this.store.flush();
    } catch (error) {
      console.error(`StudyRepository: failed to clear state: ${error}`);
    }
  }
}
