import assert from 'node:assert/strict';
import {writeFileSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';
import {Gua} from './gua-client.mjs';
const dir=process.env.FACTORY_EVIDENCE??'output/exploration'; mkdirSync(dir,{recursive:true});
const client=await new Gua().connect(process.env.GUA_BRIDGE_URL);
const result={scenario:'factory-scenario-1',seed:112,build:{sha256:process.env.FACTORY_BUILD_SHA256,commit:process.env.FACTORY_COMMIT},checks:[],cases:[]};
async function start(bug='') {
  let state=await client.observe();
  if(state.mode==='play'&&!state.paused) await client.click('pause');
  await client.click('reset');
  for(const id of ['B01_PLATFORM_RESPAWN','B02_CARGO_LOSS','B03_DOUBLE_RESULT']) await client.action('set_checked',{nodeId:id,checked:id===bug});
  await client.click('start');
}
async function release() {await client.action('release_all_game_inputs');}
async function x() {return (await client.world()).robot.position.x;}
async function moveTo(target) {
  for(let i=0;i<300;i++) {
    const delta=target-await x();
    if(Math.abs(delta)<0.005) {await client.input('move',0);return;}
    const state=await client.observe();
    await client.input('move',Math.max(-1,Math.min(1,delta/((state.carrying?174:245)/60))));
    await client.step(1);
  }
  throw new Error('Unable to approach position using ordinary movement');
}
async function routeToDock() {
  let stage=-1,jumps=0,until=0,values={};
  for(let i=0;i<1800;i++) {
    const s=await client.observe(),px=await x();
    if(s.stage===2&&px>1420) {await release();return;}
    if(s.stage!==stage) {stage=s.stage;jumps=0;until=0;}
    if(jumps<3&&px>=[330,465,630][jumps]&&s.grounded) {until=s.frame+44;jumps++;}
    const period=s.stage<2?240:180,safe=(s.frame+s.seed%60)%period<50;
    const requested={move:px>1035&&px<1070&&!safe?0:1,jump:s.frame<until,interact:!s.carrying&&px>=140&&px<190};
    for(const [id,value] of Object.entries(requested)) if(values[id]!==value) {await client.input(id,value);values[id]=value;}
    await client.step(2);
  }
  throw new Error('Route did not reach final dock');
}
try {
  // Goal-constrained exploration: place cargo, fall, recover and pick it up again.
  await start(); await moveTo(145); await client.input('interact',true); await client.step(1); await release();
  assert.equal((await client.observe()).carrying,true);
  await moveTo(480); await client.input('interact',true); await client.step(1); await release();
  assert.equal((await client.observe()).carrying,false);
  await client.input('move',1);
  for(let i=0;i<180;i++) {if((await client.observe()).deaths>0)break;await client.step(2);}
  await release(); await client.step(2);
  let state=await client.observe();
  assert.equal(state.deaths,1); assert.equal(state.cargo_lost,false);assert.equal(state.softlocked,false);
  await moveTo(145);await client.input('interact',true);await client.step(1);await release();
  assert.equal((await client.observe()).carrying,true);
  result.checks.push('X01 place/fall/respawn/recover via ordinary input');
  result.cases.push({test:'X01',state:await client.observe(),world:await client.world()});
  for(const bug of ['', 'B03_DOUBLE_RESULT']) {
    await start(bug); await routeToDock();
    await moveTo(1480);
    state=await client.observe();
    const phase=(state.frame+state.seed%60)%180;
    await client.step((111-phase+180)%180);
    await moveTo(1499); // 7 ordinary movement ticks, still in the safe phase.
    state=await client.observe();
    const beforePhase=(state.frame+state.seed%60)%180;
    assert.ok(beforePhase<=119,'Approach must end before hazard activation');
    if(beforePhase<119) await client.step(119-beforePhase);
    const before=await client.observe();
    await client.input('move',1);await client.step(1);await release();
    const after=await client.observe();
    assert.equal(after.deaths,before.deaths+1,'Actual danger contact must occur');
    assert.equal(after.deliveries,before.deliveries+(bug?1:0),'Death must prevent delivery in normal build');
    assert.equal(after.outcomes,before.outcomes+(bug?2:1),'Single versus double outcome');
    result.checks.push(`E10 same-tick goal/death ${bug||'NORMAL'}`);
    result.cases.push({bug,before,after,position:await x()});
  }
  result.status='passed';
}catch(error){result.status='failed';result.error=String(error);process.exitCode=1;}
finally{await release().catch(()=>{});client.save(dir,'exploration-wire.json');writeFileSync(join(dir,'exploration-result.json'),JSON.stringify(result,null,2));client.close();}
console.log(JSON.stringify({status:result.status,checks:result.checks,error:result.error,evidence:dir}));
