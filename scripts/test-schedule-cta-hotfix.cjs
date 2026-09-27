const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const ets = path.join(root, 'entry/src/main/ets');
const card = fs.readFileSync(path.join(ets, 'components/ScheduleImportCard.ets'), 'utf8');
const profile = fs.readFileSync(path.join(ets, 'pages/ProfileSetupPage.ets'), 'utf8');
const plan = fs.readFileSync(path.join(ets, 'pages/PlanPage.ets'), 'utf8');
const learning = fs.readFileSync(path.join(ets, 'pages/LearningHubPage.ets'), 'utf8');
const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');

// Both schedule states share one real image-picker CTA and render no scan-only entry.
assert.equal(card.includes('智能扫描'), false);
assert.equal(card.includes('重新扫描'), false);
assert.equal(card.includes('onScanDocument'), false);
assert.ok(card.includes("this.setupScheduleReady ? '重新上传课表' : '直接选择课表截图'"));
assert.match(card, /Button\(this\.setupScheduleReady \? '重新上传课表' : '直接选择课表截图'\)[\s\S]*?this\.onSelectImage\(\);/);

// Every production host reuses ScheduleImportCard without a second scan callback.
for (const source of [profile, plan, learning]) {
  assert.ok(source.includes('ScheduleImportCard({'));
  assert.equal(source.includes('onScanDocument'), false);
  assert.equal(source.includes('onScanSchedule'), false);
  assert.ok(source.includes('onSelectImage'));
}

// The picker still reaches the existing import pipeline; schedule truth guards stay intact.
assert.match(index, /private async importScheduleImage\(\): Promise<void>/);
assert.match(index, /ScheduleImportClient\.selectAndRecognize\(\)/);
assert.match(index, /this\.setupScheduleReady = true/);
assert.equal(index.includes('智能扫描'), false);
assert.equal(index.includes('重新扫描'), false);
assert.match(learning, /this\.setupScheduleReady && this\.scheduleItems\.length > 0/);
assert.match(learning, /!item\.id\.startsWith\('demo-'\)/);

console.log('PASS schedule CTA hotfix: one real image-picker entry, no smart/rescan UI');
