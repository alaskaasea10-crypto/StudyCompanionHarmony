const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const root = path.resolve(__dirname, '..');
const etsRoot = path.join(root, 'entry/src/main/ets');
const repositorySource = fs.readFileSync(path.join(etsRoot, 'services/StudyRepository.ets'), 'utf8');
const box = {
  exports: {},
  console,
  JSON,
  require: name => name === '@kit.ArkData' ? { preferences: {} } : {}
};
vm.runInNewContext(ts.transpileModule(repositorySource, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);

const StudyRepository = box.exports.StudyRepository;
let stored = '';
let failFlush = false;
const store = {
  get: async (_key, fallback) => stored.length > 0 ? stored : fallback,
  put: async (_key, value) => { stored = value; },
  flush: async () => { if (failFlush) { throw new Error('disk full'); } },
  delete: async () => { stored = ''; }
};

(async () => {
  const repository = new StudyRepository(store);
  assert.equal(await repository.load(), undefined, 'a new install has no completed local profile snapshot');

  const snapshot = {
    schemaVersion: 9,
    profileCompleted: true,
    profileName: '真实昵称',
    profileMajor: '计算机科学与技术',
    profileSubject: '线性代数',
    tasks: [{ id: 'task-real', title: '矩阵复习', subject: '线性代数', minutes: 25, completed: false }]
  };
  await repository.saveChecked(snapshot);
  const restored = await repository.load();
  assert.equal(restored.profileName, '真实昵称', 'nickname must survive a repository reload');
  assert.equal(restored.profileCompleted, true, 'completed setup must survive a repository reload');
  assert.equal(restored.tasks[0].id, 'task-real', 'profile persistence must preserve the real task identity');

  const previous = stored;
  failFlush = true;
  await assert.rejects(repository.saveChecked({ ...snapshot, profileName: '不应覆盖' }));
  failFlush = false;
  assert.equal(stored, previous, 'failed profile writes must roll back instead of overwriting the user snapshot');

  const appRoot = fs.readFileSync(path.join(etsRoot, 'pages/AppRoot.ets'), 'utf8');
  const index = fs.readFileSync(path.join(etsRoot, 'pages/Index.ets'), 'utf8');
  const setup = fs.readFileSync(path.join(etsRoot, 'pages/ProfileSetupPage.ets'), 'utf8');
  const profile = fs.readFileSync(path.join(etsRoot, 'pages/ProfilePage.ets'), 'utf8');
  const pages = fs.readFileSync(path.join(root, 'entry/src/main/resources/base/profile/main_pages.json'), 'utf8');

  assert.ok(pages.includes('pages/AppRoot'), 'the real application entry must remain AppRoot');
  assert.ok(appRoot.includes("import { Index } from './Index';"));
  assert.ok(appRoot.includes('Index({'), 'the current product mounts the local profile application directly');
  assert.ok(!appRoot.includes('AccountSession') && !index.includes('AccountSession'),
    'the current product must not pretend that the unused legacy account namespace is active');

  assert.ok(index.includes("preferences.getPreferences(hostContext, 'learner_profile')"),
    'the active profile uses the local learner_profile store');
  assert.ok(index.includes('const snapshot: StudyStateSnapshot | undefined = await this.repository?.load();'));
  assert.ok(index.includes('this.restoreSnapshot(snapshot);'), 'restart restores the persisted profile snapshot');
  assert.ok(index.includes("this.profileName = snapshot.profileName?.trim().length > 0 ? snapshot.profileName : '小林';"),
    'stored nicknames take precedence over the setup placeholder');
  assert.ok(index.includes('this.profileName = this.profileName.trim();'));
  assert.ok(index.includes('this.profileCompleted = true;'));
  assert.ok(index.includes('await this.persistState();'), 'profile completion is saved through the repository path');

  const resetStart = index.indexOf('private async resetProfile()');
  const resetEnd = index.indexOf('private hostAbilityContext()', resetStart);
  const reset = index.slice(resetStart, resetEnd);
  assert.ok(reset.includes('this.profileSetupEditing = true;'));
  assert.ok(!reset.includes('this.profileCompleted = false;'),
    'editing an existing profile must not reset the completed onboarding marker');
  assert.ok(!reset.includes("this.profileName = ''"),
    'resetting setup must not silently erase the user nickname');

  assert.ok(setup.includes("this.onTextChange('name', value);"), 'setup edits the real profile nickname');
  assert.equal(setup.includes("this.onTextChange('subject', value);"), false,
    'setup subject is selected from fixed choices and never opens a free-text editor');
  assert.ok(setup.includes("this.ChoiceChip('subject', '高等数学', '高等数学')"));
  assert.ok(setup.includes("this.ChoiceChip('minutes', '300', '5小时')"));
  assert.ok(index.includes('this.syncProfileToAcademicGoal();'),
    'reset setup updates the current persisted academic goal instead of rebuilding it');
  assert.ok(setup.includes('this.onSaveProfile();'), 'setup requires explicit confirmation');
  assert.ok(profile.includes('Text(this.profileName)'), 'the profile page renders the persisted nickname');
  assert.ok(index.includes('if (!this.profileLoaded)') &&
    index.includes('!this.profileCompleted || this.profileSetupEditing') && index.includes('ProfileSetupPageView({'),
    'first initialization stays in setup until local profile loading completes');

  console.log('PASS account/profile: current AppRoot, explicit first setup, local persistence, restart restore, rollback and reset preservation');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
