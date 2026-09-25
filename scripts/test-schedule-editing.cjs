const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
function loadService(relative) {
  const box = { exports: {}, require: () => ({}) };
  const source = fs.readFileSync(path.join(root, relative), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, box);
  return box.exports;
}

const { ScheduleEditingService: schedule } = loadService('entry/src/main/ets/services/ScheduleEditingService.ets');
const original = [
  { id: 'course-a', weekday: 1, startTime: '14:00', endTime: '16:00', course: '高等数学', location: '教一-201' },
  { id: 'course-b', weekday: 3, startTime: '09:00', endTime: '10:30', course: '大学英语', location: '教二-305' }
];
const changed = schedule.replace(original, { ...original[0], startTime: '15:00', endTime: '17:00' });
assert.equal(changed[0].id, 'course-a');
assert.equal(changed[0].startTime, '15:00');
assert.equal(changed[0].endTime, '17:00');
assert.equal(original[0].startTime, '14:00');

const added = schedule.add(changed, 123456);
assert.equal(added.length, 3);
assert.equal(added[2].id, 'schedule-manual-123456');
assert.equal(schedule.add(added, 123456)[3].id, 'schedule-manual-123456-1');
const removed = schedule.remove(added, 'schedule-manual-123456');
assert.equal(removed.length, 2);
assert.ok(removed.every(item => item.id !== 'schedule-manual-123456'));
assert.equal(schedule.remove([original[0]], 'course-a').length, 1);

assert.equal(schedule.validationError(changed), '');
assert.match(schedule.validationError([{ ...original[0], endTime: '13:00' }]), /结束时间/);
assert.match(schedule.validationError([{ ...original[0], startTime: '25:00' }]), /HH:mm/);
const prepared = schedule.prepare([{ ...original[1], course: '  大学英语  ' }, changed[0]]);
assert.equal(prepared[0].id, 'course-a');
assert.equal(prepared[1].course, '大学英语');

const indexSource = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
assert.match(indexSource, /scheduleItems:\s*this\.scheduleItems/);
assert.match(indexSource, /private async saveScheduleEdits\(items: ScheduleItem\[\]\)/);
assert.match(indexSource, /this\.scheduleItems = prepared/);
assert.match(indexSource, /await this\.persistState\(\)/);
assert.match(indexSource, /Array\.isArray\(snapshot\.scheduleItems\)/);

const titleMap = fs.readFileSync(path.join(root, 'entry/src/main/ets/utils/SubjectDisplayName.ets'), 'utf8');
for (const title of ['FinalReview', 'EnglishHomework', 'MatrixChapterReview']) {
  assert.equal(titleMap.includes(title), false, `${title} must remain user data, not a subject mapping`);
}
console.log('PASS schedule editing: stable identity, add/delete, validation, shared persisted source and no title-translation hack');
