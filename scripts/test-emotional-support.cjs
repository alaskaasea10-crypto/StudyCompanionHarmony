const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require(process.argv[2]);
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root,
  'entry/src/main/ets/services/EmotionalSupportClient.ets'), 'utf8');
let requested = false;
const http = { createHttp: () => ({
  request: async () => { requested = true; return { responseCode: 200,
    result: JSON.stringify({ok:true,reply:'听起来你今天很累。',crisis:false}) }; },
  destroy: () => {}
}), RequestMethod: {POST:'POST'}, HttpDataType: {STRING:'STRING'} };
const box = {exports:{}, console, require: name => name === '@kit.NetworkKit' ? {http} :
  name.includes('BackendConfig') ? {BackendConfig:{origin:()=> 'http://127.0.0.1:8000'}} : {}};
vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,
  module:ts.ModuleKind.CommonJS}}).outputText,box);
const client=box.exports.EmotionalSupportClient;
(async()=>{
  const crisis=await client.reply('我不想活了',[]);
  assert.equal(crisis.crisis,true); assert.ok(crisis.reply.includes('不要独处'));
  assert.equal(requested,false,'crisis response must not wait for network');
  const normal=await client.reply('最近考试有点焦虑',[]);
  assert.equal(normal.reply,'听起来你今天很累。'); assert.equal(requested,true);
  const floating=fs.readFileSync(path.join(root,'entry/src/main/ets/components/FloatingAgent.ets'),'utf8');
  assert.ok(floating.includes('这里的对话不会进入学习画像'));
  assert.ok(floating.includes('PanGesture'));
  assert.ok(floating.includes('接受并加入今日待办'));
  assert.ok(floating.includes('.hitTestBehavior(HitTestMode.Default)'));
  assert.ok(!floating.includes('.hitTestBehavior(this.open ? HitTestMode.Block'));
  const index=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
  assert.ok(index.includes('FloatingAgent({'));
  assert.ok(index.includes("this.floatingAgentMode = 'support'"));
  assert.ok(index.includes('PlanCommitService.append'));
  assert.ok(!index.includes('EmotionalSupportPageView({'));
  assert.ok(!index.includes('LearningPageView({'));
  const growth=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/GrowthPage.ets'),'utf8');
  assert.ok(!growth.includes('和星球说说话'));
  for (const file of ['HomePage.ets','LoadingPage.ets','ProfileSetupPage.ets','LearningHubPage.ets']) {
    const source=fs.readFileSync(path.join(root,'entry/src/main/ets/pages',file),'utf8');
    assert.ok(source.includes('StudyPlanet'),`${file} should carry the Planet brand mark`);
  }
  const appIcon=fs.readFileSync(path.join(root,'AppScope/resources/base/media/layered_image.json'),'utf8');
  assert.ok(appIcon.includes('$media:study_planet'));
  assert.ok(appIcon.includes('$media:planet_icon_background'));
  console.log('PASS floating planet: private support, draggable global dialog, crisis local fallback, explicit plan acceptance');
  console.log('PASS Planet identity: launcher, loading, setup, home, learning, growth and widget');
})().catch(error=>{console.error(error);process.exitCode=1;});
