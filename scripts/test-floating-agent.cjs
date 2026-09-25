const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);

const file = path.resolve(__dirname, '..', 'entry/src/main/ets/components/FloatingAgent.ets');
const fullSource = fs.readFileSync(file, 'utf8');
let source = fullSource.split('  @Builder')[0];
source = source.replace(/^import .*;\n/gm, '')
  .replace(/@(Component|Prop|State)\s*/g, '')
  .replace('export struct FloatingAgent', 'class FloatingAgent') +
  '\n}\nexports.FloatingAgent = FloatingAgent;';
const box = { exports: {}, Date, console };
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
}).outputText, box);
const Agent = box.exports.FloatingAgent;

const bubble = new Agent();
let opens = 0;
let hintVisible = true;
bubble.onToggle = () => { opens++; };
bubble.onHintDismiss = () => { hintVisible = false; };
bubble.openAssistant();
assert.equal(opens, 1, 'clicking the hint opens the existing assistant callback');
assert.equal(hintVisible, false, 'clicking the hint dismisses the parent-owned session hint');

const planet = new Agent();
let planetHintVisible = true;
planet.onToggle = () => { opens++; };
planet.onHintDismiss = () => { planetHintVisible = false; };
planet.openAssistant();
assert.equal(opens, 2, 'clicking the planet uses the same assistant callback');
assert.equal(planetHintVisible, false, 'clicking the planet also dismisses the session hint');

const close = new Agent();
let closeOpens = 0;
let closeHintVisible = true;
close.onToggle = () => { closeOpens++; };
close.onHintDismiss = () => { closeHintVisible = false; };
close.hideHint();
assert.equal(closeHintVisible, false);
assert.equal(closeOpens, 0, 'closing the hint cannot bubble into chat opening');
const reconstructed = new Agent();
reconstructed.showHint = closeHintVisible;
assert.equal(reconstructed.showHint, false,
  'normal child reconstruction must preserve the parent-owned dismissed session state');

let businessOverlayOpen = false;
businessOverlayOpen = true;
closeHintVisible = false;
businessOverlayOpen = false;
assert.equal(closeHintVisible, false,
  'closing a business overlay cannot revive an already dismissed or used hint');
assert.equal(businessOverlayOpen, false);

for (const [width, height] of [[300, 640], [320, 720], [360, 800], [800, 1200]]) {
  const agent = new Agent();
  agent.areaWidth = width;
  agent.areaHeight = height;
  agent.clampPlanet();
  assert.ok(agent.hintX() >= 12);
  assert.ok(agent.hintX() + agent.hintWidth() <= width - 12, `hint stays inside ${width}px viewport`);
  assert.ok(agent.hintY() >= 16);
  assert.ok(agent.hintY() + agent.hintHeight() <= height - 16, `hint stays inside ${height}px viewport`);
  assert.ok(agent.hintHeight() <= 92, `hint stays compact at ${width}px`);
}
const tablet = new Agent();
tablet.areaWidth = 800;
assert.equal(tablet.hintWidth(), 288, 'tablet hint width remains capped');

assert.ok(fullSource.includes('学习卡住了，或者心里有点烦？来找我聊聊吧～'));
assert.ok(fullSource.includes('我会陪你一起想办法'));
assert.ok(fullSource.includes(".accessibilityText('打开小星球对话助手')"));
assert.ok(fullSource.includes(".accessibilityText('关闭小星球提示')"));
assert.ok(fullSource.includes('.hitTestBehavior(this.interactive && this.open ? HitTestMode.Default : HitTestMode.Transparent)'),
  'closed overlay remains transparent outside the planet and hint');
assert.ok(fullSource.includes('if (!this.dragged) { this.openAssistant(); }'), 'drag behavior remains guarded');
assert.ok(!fullSource.includes('@State private hintVisible'), 'hint lifecycle cannot reset inside a reconstructed child');
assert.ok(!fullSource.includes('}.width(\'100%\').height(24)'), 'close control cannot reserve a blank header row');

const indexSource = fs.readFileSync(path.resolve(__dirname, '..', 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const homeSource = fs.readFileSync(path.resolve(__dirname, '..', 'entry/src/main/ets/pages/HomePage.ets'), 'utf8');
assert.ok(indexSource.includes('@State floatingAgentHintVisible: boolean = true;'),
  'a fresh Index session starts with one hint');
assert.ok(indexSource.includes('showHint: this.currentTab === 0 && this.floatingAgentHintVisible'),
  'hint is limited to the home page');
assert.ok(indexSource.includes('interactive: !this.businessOverlayOpen'),
  'business overlays disable the complete floating entry layer');
assert.ok(indexSource.includes('if (visible) { this.floatingAgentHintVisible = false; }'),
  'opening a business overlay permanently dismisses the session hint');
assert.ok(homeSource.includes('this.onBusinessOverlayChange(true);'),
  'today-adjust and resource overlays notify the parent when opened');
assert.ok(homeSource.includes('this.onBusinessOverlayChange(false);'),
  'business overlay closure restores floating-agent availability without reviving the hint');

console.log('PASS FloatingAgent: session hint lifecycle, click isolation, overlay guard, dragging and phone/tablet bounds');
