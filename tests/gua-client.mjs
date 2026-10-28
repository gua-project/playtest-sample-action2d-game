import {writeFileSync, mkdirSync} from 'node:fs';
import {join} from 'node:path';
export const delay = ms => new Promise(r => setTimeout(r, ms));
export class Gua {
  next = 1; pending = new Map(); history = [];
  async connect(url = 'ws://127.0.0.1:18241') {
    this.socket = new WebSocket(url);
    await new Promise((resolve,reject) => {this.socket.onopen=resolve; this.socket.onerror=reject;});
    this.socket.onmessage = event => {
      const message = JSON.parse(event.data);
      this.pending.get(message.id)?.(message); this.pending.delete(message.id);
    };
    return this;
  }
  async request(type, args = {}) {
    const id = this.next++;
    const request = {id,type,...args};
    const result = await new Promise((resolve,reject) => {
      const timeout = setTimeout(() => {this.pending.delete(id); this.socket.close(); reject(new Error(`Timeout ${type}; connection invalidated`));}, 6000);
      this.pending.set(id, response => {clearTimeout(timeout); resolve(response);});
      this.socket.send(JSON.stringify(request));
    });
    this.history.push({time:new Date().toISOString(),request,response:result});
    if (!result.ok) throw new Error(JSON.stringify(result));
    return result.result;
  }
  async action(type,args) {
    const receipt = await this.request(type,args);
    if (!receipt?.requestId) return receipt;
    const poll = type.includes('game_input') ? 'poll_game_input' : 'poll_events';
    for(let i=0;i<500;i++) {
      const result=await this.request(poll,{requestId:receipt.requestId});
      if(result && (poll==='poll_events' || result.completed)) {
        if(!result.succeeded) throw new Error(JSON.stringify(result));
        await this.published(); return result;
      }
      await delay(10);
    }
    throw new Error(`Incomplete action ${type}`);
  }
  async click(nodeId) {return this.action('click_node',{nodeId});}
  async published() {
    const first=await this.request('get_context_status');
    for(let i=0;i<500;i++) {
      await delay(5); const next=await this.request('get_context_status');
      if(next.sessionEpoch!==first.sessionEpoch) throw new Error('Publication epoch changed');
      if(next.frameSequence>first.frameSequence) return;
    }
    throw new Error('No fresh publication');
  }
  async input(actionId,value) {return this.action('set_game_input_action',{actionId,value,leaseMs:30000});}
  async observe() {
    const result = await this.request('get_observe_snapshot');
    if (result.document.kind !== 'snapshot' || result.document.entries.length < 18) throw new Error('Incomplete Observe snapshot');
    const state={};
    for(const entry of result.document.entries) {
      if(entry.status !== 'available') throw new Error(`Unavailable observation ${JSON.stringify(entry)}`);
      state[entry.name] = entry.value.value;
    }
    return state;
  }
  async world() {
    const tree = await this.request('get_world_object_tree');
    if(tree.objects.length!==6) throw new Error('Missing world objects');
    return Object.fromEntries(tree.objects.map(o=>[o.id,o]));
  }
  async step(ticks) {
    let clock=await this.request('clock_run_for',{durationMs:ticks*1000/60,stepMs:1000/60});
    const seq=clock.operationSequence, epoch=clock.completionSessionEpoch, frame=clock.completionAfterFrameSequence;
    if(seq===undefined || epoch===undefined || frame===undefined) throw new Error('Missing clock completion metadata');
    for(let i=0;i<500;i++) {
      const context=await this.request('get_context_status');
      if(context.sessionEpoch!==epoch) throw new Error('Clock epoch changed');
      if(clock.completedOperationSequence>=seq && context.frameSequence>frame) return;
      await delay(5); clock=await this.request('get_clock');
    }
    throw new Error('Incomplete clock run');
  }
  save(dir,name='wire.json') {mkdirSync(dir,{recursive:true}); writeFileSync(join(dir,name),JSON.stringify(this.history,null,2));}
  close() {this.socket.close();}
}
