import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {Gua} from './gua-client.mjs';
const dir=process.env.FACTORY_EVIDENCE??'output/exe-fixed';
const saved=JSON.parse(readFileSync(join(process.env.FACTORY_SAVE_DIR,'factory-save.json'),'utf8')).game;
const client=await new Gua().connect(process.env.GUA_BRIDGE_URL);
const result={test:'E09 fresh process save restore'};
try {
  assert.equal((await client.observe()).mode,'title');
  await client.click('load');
  const state=await client.observe(), world=await client.world();
  for(const key of ['frame','stage','seed','deaths','deliveries','carrying','checkpoint']) assert.deepEqual(state[key],saved[key],key);
  assert.equal(state.paused,true);
  assert.deepEqual(world.robot.position,{x:saved.pos[0],y:saved.pos[1]});
  result.status='passed'; result.state=state;
} catch(error) {result.status='failed'; result.error=String(error);process.exitCode=1;}
finally {client.save(dir,'restart-wire.json');writeFileSync(join(dir,'restart-result.json'),JSON.stringify(result,null,2));client.close();}
console.log(JSON.stringify(result));
