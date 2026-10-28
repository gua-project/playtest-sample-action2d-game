import assert from 'node:assert/strict';
import {writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {Gua,delay} from './gua-client.mjs';
const dir=process.env.FACTORY_EVIDENCE;
const client=await new Gua().connect(process.env.GUA_BRIDGE_URL);
const result={test:'R01 real-time EXE normal-input route',scenario:'factory-scenario-1',seed:112,bugs:[],build:{sha256:process.env.FACTORY_BUILD_SHA256,commit:process.env.FACTORY_COMMIT},samples:[]};
const started=Date.now();
try {
  assert.equal((await client.request('get_clock')).installed,false,'Real-time run must not install virtual time');
  await client.click('start');
  let stage=-1,jumps=0,until=0,values={},iteration=0;
  while(Date.now()-started<120000) {
    const state=await client.observe(),world=await client.world(),px=world.robot.position.x;
    if(iteration++%25===0) result.samples.push({elapsedMs:Date.now()-started,state,position:world.robot.position});
    if(state.mode==='result') {result.final=state;break;}
    assert.equal(state.deaths,0,'Agent policy should avoid hazards');
    if(state.stage!==stage) {stage=state.stage;jumps=0;until=0;}
    if(jumps<3&&px>=[330,465,630][jumps]&&state.grounded) {until=state.frame+44;jumps++;}
    const period=state.stage<2?240:180,safe=(state.frame+state.seed%60)%period<50;
    let move=px>1035&&px<1070&&!safe?0:1;
    if(state.stage===2&&px>1450&&px<1480&&!safe)move=0;
    const requested={move,jump:state.frame<until,interact:!state.carrying&&px>=140&&px<190};
    for(const [id,value]of Object.entries(requested))if(values[id]!==value){await client.input(id,value);values[id]=value;}
    await delay(15);
  }
  assert.equal(result.final?.deliveries,3,'Complete 3 deliveries within 120 seconds');
  assert.equal(result.final.deaths,0);
  result.status='passed';
}catch(error){result.status='failed';result.error=String(error);process.exitCode=1;}
finally{result.elapsedMs=Date.now()-started;await client.action('release_all_game_inputs').catch(()=>{});client.save(dir,'realtime-wire.json');writeFileSync(join(dir,'realtime-result.json'),JSON.stringify(result,null,2));client.close();}
console.log(JSON.stringify({test:result.test,status:result.status,elapsedMs:result.elapsedMs,error:result.error}));
