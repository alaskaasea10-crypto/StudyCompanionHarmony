const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const ts=require(process.argv[2]),root=path.resolve(__dirname,'..'),cache=new Map(),stores=new Map();
let nativeID='user-a',badState=false,cancel=false,failName='';
const prefs={getPreferences:async(_ctx,name)=>{
  if(!stores.has(name))stores.set(name,new Map());const data=stores.get(name);
  return {get:async(k,d)=>data.has(k)?data.get(k):d,put:async(k,v)=>data.set(k,v),
    flush:async()=>{if(name===failName)throw Error('disk full');}};
}};
const authentication={HuaweiIDProvider:class{createLoginWithHuaweiIDRequest(){return {}; }},
  AuthenticationController:class{async executeRequest(r){if(cancel)throw {code:100};return {state:badState?'bad':r.state,data:{openID:nativeID}};}}};
const cryptoFramework={createRandom:()=>({generateRandomSync:n=>({data:new Uint8Array(crypto.randomBytes(n))})}),
  createMd:()=>{const h=crypto.createHash('sha256');return {update:async b=>h.update(b.data),digest:async()=>({data:new Uint8Array(h.digest())})};}};
function load(name){if(cache.has(name))return cache.get(name);const box={exports:{},Error,Uint8Array,
  require:s=>s==='@kit.AccountKit'?{authentication}:s==='@kit.CryptoArchitectureKit'?{cryptoFramework}:
    s==='@kit.ArkTS'?{util:{TextEncoder:class{encodeInto(s){return new Uint8Array(Buffer.from(s));}}}}:
    s==='@kit.ArkData'?{preferences:prefs}:s.startsWith('@kit.')?{}:load(path.basename(s))};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(root,`entry/src/main/ets/services/${name}.ets`),'utf8'),{
    compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,box);
  cache.set(name,box.exports);return box.exports;}
(async()=>{
  const {AccountSession:s}=load('AccountSession'),{AccountArchive:a}=load('AccountArchive');
  assert.equal(s.owner(),'');assert.equal(s.storeName('learner_profile'),'learner_profile');
  const first=await s.authorize({});assert.match(first,/^[a-f0-9]{64}$/);assert.ok(!first.includes('user-a'));
  s.select(first);assert.notEqual(s.storeName('learner_profile'),'learner_profile');
  nativeID='user-b';const second=await s.authorize({});assert.notEqual(first,second);
  badState=true;await assert.rejects(s.authorize({}));badState=false;
  cancel=true;await assert.rejects(s.authorize({}));cancel=false;
  assert.equal(s.owner(),first,'authorization alone must not change account');
  assert.throws(()=>s.select('../other'));s.select('');
  const bases=['learner_profile','matrix_question_bank_v1','learning_video_library'];
  const keys=['study_state_v1','records','records'];
  const values=['{"profileName":"guest"}','{"version":1,"sessions":[]}','{"favoriteIds":["x"],"watchedIds":[]}'];
  for(let i=0;i<3;i++)await (await prefs.getPreferences({},bases[i])).put(keys[i],values[i]);
  await a.prepare({},first,true);assert.equal(await a.exists({},first),true);
  for(let i=0;i<3;i++)assert.equal(await (await prefs.getPreferences({},s.storeName(bases[i],first))).get(keys[i],''),values[i]);
  await (await prefs.getPreferences({},'learner_profile')).put('study_state_v1','changed');
  await a.prepare({},first,true);
  assert.equal(stores.get(s.storeName('learner_profile',first)).get('study_state_v1'),values[0],'existing account never overwritten');
  failName=s.storeName('learning_video_library',second);
  await assert.rejects(a.prepare({},second,true));assert.equal(await a.exists({},second),false);
  failName='';await a.prepare({},second,false);assert.equal(await a.exists({},second),true);
  assert.equal(stores.get(s.storeName('learner_profile',second)).get('study_state_v1'),'');
  assert.equal(JSON.parse(stores.get(s.storeName('matrix_question_bank_v1',second)).get('records')).sessions.length,0);
  assert.equal(stores.get('learner_profile').get('study_state_v1'),'changed','guest is retained');
  const page=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/Index.ets'),'utf8');
  assert.ok(page.includes("AccountSession.storeName('learner_profile', this.ownerScope)"));
  assert.ok(page.includes('this.repository.saveChecked(this.snapshot())'));
  assert.ok(page.includes('this.ownerScope === AccountSession.owner()'));
  const gate=fs.readFileSync(path.join(root,'entry/src/main/ets/pages/AccountRoot.ets'),'utf8');
  assert.ok(gate.includes('current !== owner'));assert.ok(gate.includes('owner !== this.pendingOwner'));
  assert.ok(!fs.readFileSync(path.join(root,'entry/src/main/ets/services/AccountSession.ets'),'utf8').includes('console.'));
  const gateLogic=gate.split('  build() {')[0].replace(/^import .*;\n/gm,'')
    .replace('@Entry\n@Component\nstruct AccountRoot','class AccountRoot').replace(/@State /g,'')+'}\nexports.Gate=AccountRoot;';
  const gateBox={exports:{},Error,AccountSession:s,AccountArchive:a,
    notificationManager:{cancelAll:async()=>{}},StudyWidgetService:{clearPrivateData:async()=>{}},
    AppStorage:{setOrCreate:()=>{}}};
  vm.runInNewContext(ts.transpileModule(gateLogic,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText,gateBox);
  const g=new gateBox.exports.Gate();g.getUIContext=()=>({getHostContext:()=>({eventHub:{on:()=>{},off:()=>{}}})});
  g.aboutToAppear();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(g.contentVisible,false,'cold start must show identity choice before mounting profile setup');
  assert.equal(s.owner(),'','cold start must not silently restore an account');
  cancel=true;await g.login();cancel=false;
  assert.equal(g.contentVisible,false,'cancelled login must not bypass identity choice');
  await g.guest();assert.equal(g.contentVisible,true,'guest entry requires an explicit choice');
  g.contentVisible=false;
  nativeID='user-a';await g.login();assert.equal(g.contentVisible,true);assert.equal(s.owner(),first);
  nativeID='user-b';await g.checkForeground();assert.equal(g.contentVisible,false);assert.equal(g.signedIn,false);assert.equal(s.owner(),'');
  await g.guest();assert.equal(g.contentVisible,true);assert.equal(s.owner(),'');
  g.contentVisible=false;nativeID='new-user';await g.login();assert.ok(g.pendingOwner);assert.equal(s.owner(),'');
  nativeID='changed-during-consent';await g.prepare(true);assert.equal(g.contentVisible,false);assert.equal(s.owner(),'');
  await g.guest();assert.equal(g.pendingOwner,'');
  nativeID='user-a';await g.login();cancel=true;await g.checkForeground();cancel=false;
  assert.equal(g.contentVisible,false);assert.equal(s.owner(),'');
  console.log('PASS: native state/cancel checks, hashed namespaces, explicit activation, separate accounts, migration/no-overwrite/failure retry, guest preservation');
  console.log('PASS: cold-start identity gate before profile setup, cancelled login stays gated, explicit guest entry, account login, foreground revocation/change, migration identity recheck, guest return');
})().catch(e=>{console.error(e);process.exitCode=1;});
