export class FocusClock {
  static remainingSeconds(totalSeconds: number, elapsedSeconds: number, segmentStartedAt: number,
    now: number): number {
    const activeSeconds: number = segmentStartedAt > 0 ?
      Math.max(0, Math.floor((now - segmentStartedAt) / 1000)) : 0;
    return Math.max(0, totalSeconds - elapsedSeconds - activeSeconds);
  }

  static elapsedSeconds(storedElapsedSeconds: number, segmentStartedAt: number, now: number): number {
    if (segmentStartedAt <= 0) {
      return storedElapsedSeconds;
    }
    return storedElapsedSeconds + Math.max(0, Math.floor((now - segmentStartedAt) / 1000));
  }

  static completedMinutes(elapsedSeconds: number): number {
    if (elapsedSeconds <= 0) {
      return 0;
    }
    return Math.max(1, Math.round(elapsedSeconds / 60));
  }
}
