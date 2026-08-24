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
      return JSON.parse(raw) as StudyStateSnapshot;
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

  async clear(): Promise<void> {
    try {
      await this.store.delete(STATE_KEY);
      await this.store.flush();
    } catch (error) {
      console.error(`StudyRepository: failed to clear state: ${error}`);
    }
  }
}
