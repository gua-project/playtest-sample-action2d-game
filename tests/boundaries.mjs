import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {Gua} from './gua-client.mjs';

const dir=process.env.FACTORY_EVIDENCE??'output/boundaries';
mkdirSync(dir,{recursive:true});
const client=await new Gua().connect(process.env.GUA_BRIDGE_URL);
const result={scenario:'factory-scenario-1',seed:112,bugs:[],build:{sha256:process.env.FACTORY_BUILD_SHA256,commit:process.env.FACTORY_COMMIT},checks:[],cases:[]};
async function release(){await client.action('release_all_game_inputs');}
async function reset(){
  await release();
  const state=await client.observe();
  if(state.mode==='play'&&!state.paused)await client.click('pause');
  await client.click('reset');
  for(const id of ['B01_PLATFORM_RESPAWN','B02_CARGO_LOSS','B03_DOUBLE_RESULT'])await client.action('set_checked',{nodeId:id,checked:false});
  await client.click('start');
}
async function position(){return (await client.world()).robot.position;}
async function approach(target){
  for(let i=0;i<180;i++){
    const delta=target-(await position()).x;
    if(Math.abs(delta)<0.005){await client.input('move',0);return;}
    await client.input('move',Math.max(-1,Math.min(1,delta/(245/60))));
    await client.step(1);
  }
  throw new Error('Ordinary movement did not approach edge');
}
try{
  const version=await client.request('get_version');
  assert.equal(version.coreVersion,'1.1.2');
  for(const delayTicks of [2,8]){
    await reset();await approach(505);await client.input('move',1);
    for(let i=0;i<5;i++){
      await client.step(1);
      if(!(await client.observe()).grounded)break;
    }
    assert.equal((await client.observe()).grounded,false,'Must actually leave the floor');
    await client.step(delayTicks);await client.input('move',0);
    const before={state:await client.observe(),position:await position()};
    await client.input('jump',true);await client.step(1);await release();
    const after={state:await client.observe(),position:await position()};
    if(delayTicks===2)assert.ok(after.position.y<before.position.y,'Early edge input must use coyote jump');
    else assert.ok(after.position.y>before.position.y,'Expired edge input must not create an air jump');
    assert.equal(after.state.deaths,0);
    result.checks.push(`X02 edge jump after ${delayTicks} ticks`);
    result.cases.push({delayTicks,before,after});
  }
  await reset();await client.input('move',1);
  let dead;
  for(let i=0;i<300;i++){
    await client.step(1);dead=await client.observe();
    if(dead.deaths>0)break;
  }
  assert.equal(dead.deaths,1);assert.equal(dead.pending_respawn,true);
  await release();await client.click('pause');
  const paused=await client.observe();
  await client.step(60);
  const waiting=await client.observe();
  assert.equal(waiting.frame,paused.frame);assert.equal(waiting.deaths,1);assert.equal(waiting.pending_respawn,true);
  await client.click('resume');await client.step(1);
  const resumed=await client.observe(),resumedPosition=await position();
  assert.equal(resumed.pending_respawn,false);assert.equal(resumed.deaths,1);assert.equal(resumed.softlocked,false);
  assert.deepEqual(resumedPosition,{x:64,y:478});
  await client.step(5);
  assert.equal((await client.observe()).deaths,1,'Resume must not schedule a second death or respawn');
  result.checks.push('X03 death then pause defers one respawn');
  result.cases.push({dead,paused,waiting,resumed,resumedPosition});
  result.status='passed';
}catch(error){result.status='failed';result.error=String(error);process.exitCode=1;}
finally{await release().catch(()=>{});client.save(dir,'boundaries-wire.json');writeFileSync(join(dir,'boundaries-result.json'),JSON.stringify(result,null,2));client.close();}
console.log(JSON.stringify({status:result.status,checks:result.checks,error:result.error,evidence:dir}));
