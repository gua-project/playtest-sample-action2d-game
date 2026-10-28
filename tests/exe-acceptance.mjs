import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {Gua} from './gua-client.mjs';
const dir=process.env.FACTORY_EVIDENCE ?? 'output/exe-fixed';
mkdirSync(dir,{recursive:true});
const client=await new Gua().connect(process.env.GUA_BRIDGE_URL);
const evidence={scenario:'factory-scenario-1',seed:112,bugs:[],mode:'fixed-clock',checks:[],positions:[]};
evidence.build={sha256:process.env.FACTORY_BUILD_SHA256,commit:process.env.FACTORY_COMMIT,sourceSha256:process.env.FACTORY_SOURCE_SHA256};
function check(id,value) {assert.ok(value,id); evidence.checks.push(id);}
try {
  const version=await client.request('get_version');
  evidence.gua=version;
  check('E01 pinned Gua version',['coreVersion','runtimeVersion','godotPluginVersion'].every(k=>version[k]==='1.1.2'));
  check('E01 Observe capability',version.capabilities.includes('observe_v1'));
  const subscription=await client.request('subscribe_observations');
  check('E01 subscription snapshot',subscription.snapshot.document.kind==='snapshot');
  const actions=await client.request('get_game_input_actions');
  check('E02 ordinary game input map',actions.actions.length===3 && ['move:axis1d','jump:button','interact:button'].every(pair=>actions.actions.some(a=>`${a.id}:${a.valueType}`===pair)));
  await client.click('start');
  let state=await client.observe();
  check('E03 start',state.mode==='play' && state.stage===0);
  await client.step(6);
  await client.click('pause');
  state=await client.observe();
  const stopped=state.frame;
  await client.step(60);
  check('E04 pause freezes ticks',(await client.observe()).frame===stopped);
  await client.click('save');
  const savedWorld=await client.world();
  const savedResumeLabel=(await client.request('get_ui_tree')).nodes.find(n=>n.id==='resume').label;
  await client.click('resume');
  await client.input('move',1); await client.step(30);
  await client.action('release_all_game_inputs');
  check('E05 state changed after save',(await client.observe()).frame>stopped);
  await client.click('pause');
  await client.click('language');
  await client.click('size');
  await client.click('load');
  state=await client.observe();
  check('E05 save/load restores earlier state paused',state.frame===stopped && state.paused && JSON.stringify((await client.world()).robot.position)===JSON.stringify(savedWorld.robot.position));
  const loadedUi=await client.request('get_ui_tree');
  check('E05 saved language restored',loadedUi.nodes.some(n=>n.id==='resume' && n.label===savedResumeLabel));
  await client.click('resume');
  let jumpCount=0, jumpUntil=0, priorStage=-1;
  let values={move:null,jump:null,interact:null};
  for(let iteration=0;iteration<2300;iteration++) {
    state=await client.observe();
    const world=await client.world();
    const pos=world.robot.position;
    if(iteration%40===0) evidence.positions.push({state,pos});
    if(state.mode==='result') break;
    if(state.stage!==priorStage) {priorStage=state.stage; jumpCount=0; jumpUntil=0;}
    let move=1;
    if(jumpCount<3 && pos.x>=[330,465,630][jumpCount] && state.grounded) {jumpUntil=state.frame+44; jumpCount++;}
    const period=state.stage<2?240:180;
    const safe=(state.frame+state.seed%60)%period<50;
    if(pos.x>1035&&pos.x<1070&&!safe) move=0;
    if(state.stage===2&&pos.x>1450&&pos.x<1480&&!safe) move=0;
    const requested={move,jump:state.frame<jumpUntil,interact:!state.carrying&&pos.x>=140&&pos.x<190};
    for(const [id,value] of Object.entries(requested)) {
      if(values[id]!==value) {await client.input(id,value); values[id]=value;}
    }
    await client.step(2);
  }
  state=await client.observe();
  evidence.final=state;
  check('E06 three deliveries via movement/pickup/jump',state.mode==='result'&&state.deliveries===3);
  check('E06 normal route no false death',state.deaths===0);
  const changes=await client.request('poll_observations',{subscriptionId:subscription.subscriptionId});
  // A bounded history gap is retained as evidence and never asserted as an empty success.
  evidence.subscriptionPoll={status:changes.document.status,events:changes.document.events?.length};
  await client.request('unsubscribe_observations',{subscriptionId:subscription.subscriptionId});
  await client.action('release_all_game_inputs');
  await client.click('replay');
  state=await client.observe();
  check('E07 replay',state.mode==='play'&&state.stage===0&&state.deliveries===0);
  evidence.bugComparisons=[];
  for(const bug of ['', 'B01_PLATFORM_RESPAWN', 'B02_CARGO_LOSS']) {
    await client.action('release_all_game_inputs');
    await client.click('pause'); await client.click('reset');
    for(const id of ['B01_PLATFORM_RESPAWN','B02_CARGO_LOSS','B03_DOUBLE_RESULT']) await client.action('set_checked',{nodeId:id,checked:id===bug});
    await client.click('start');
    await client.input('move',1);
    let holding=false;
    for(let i=0;i<350;i++) {
      state=await client.observe(); const world=await client.world();
      if(state.deaths>0) break;
      const pickup=!state.carrying&&world.robot.position.x>=140&&world.robot.position.x<190;
      if(pickup!==holding) {await client.input('interact',pickup); holding=pickup;}
      await client.step(2);
    }
    await client.action('release_all_game_inputs'); await client.step(2);
    state=await client.observe();
    check(`E08 fall detected ${bug||'NORMAL'}`,state.deaths===1);
    check(`E08 respawn comparison ${bug||'NORMAL'}`,state.softlocked===(bug==='B01_PLATFORM_RESPAWN'));
    check(`E08 cargo comparison ${bug||'NORMAL'}`,state.cargo_lost===(bug==='B02_CARGO_LOSS'));
    evidence.bugComparisons.push({bug,state});
  }
  evidence.status='passed';
} catch(error) {evidence.status='failed'; evidence.error=String(error); process.exitCode=1;}
finally {client.save(dir); writeFileSync(join(dir,'result.json'),JSON.stringify(evidence,null,2)); client.close();}
console.log(JSON.stringify({status:evidence.status,checks:evidence.checks,final:evidence.final,error:evidence.error,evidence:dir}));
