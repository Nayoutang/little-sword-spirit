import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {handleRequest,validatePayload,UsageGate} from './worker.mjs';
const valid = {model:'attacker-model',messages:[{role:'system',content:'你是小墨。'},{role:'user',content:'你好'}],max_tokens:100000,stream:true};
function makeGate(limits={}) {
 const db = new DatabaseSync(':memory:');
 const sql = {exec(query,...args){const statement=db.prepare(query); if (/^SELECT/.test(query)) return {toArray:()=>statement.all(...args)}; statement.run(...args); return {toArray:()=>[]};}};
 const storage={sql,transactionSync(fn){db.exec('BEGIN');try {const result=fn();db.exec('COMMIT');return result;}catch(e){db.exec('ROLLBACK');throw e;}}};
 return {gate:new UsageGate({storage},limits),storage,db};
}
function envWithGate(gate) {return {DEEPSEEK_API_KEY:'fake-test-key',MODEL_NAME:'deepseek-chat',USAGE_GATE:{idFromName:()=>0,get:()=>gate}};}
function req(payload=valid) {return new Request('https://test/v1/chat/completions',{method:'POST',headers:{'CF-Connecting-IP':'192.0.2.1'},body:JSON.stringify(payload)});}
test('validates context and clamps output, never forwards model or stream',()=>{
 const result=validatePayload(valid);assert.equal(result.max_tokens,1024);assert.equal(result.stream,false);assert.equal(result.model,undefined);
 assert.throws(()=>validatePayload({messages:[{role:'user',content:'arbitrary'}]}));
 assert.throws(()=>validatePayload({messages:[{role:'system',content:'小墨'.repeat(70000)}]}));
});
test('persistent atomic per-IP and global quotas survive gate instance replacement',async()=>{
 const {gate,storage,db}=makeGate({IP_WINDOW_LIMIT:2,IP_DAILY_LIMIT:4,GLOBAL_DAILY_LIMIT:3});
 const consume=async(g,id)=>(await (await g.fetch(new Request('https://internal',{method:'POST',body:JSON.stringify({identity:id.repeat(64)})}))).json());
 assert.equal((await consume(gate,'a')).ok,true);assert.equal((await consume(gate,'a')).ok,true);
 const restored=new UsageGate({storage},{IP_WINDOW_LIMIT:2,IP_DAILY_LIMIT:4,GLOBAL_DAILY_LIMIT:3});
 assert.equal((await consume(restored,'a')).ok,false);assert.equal((await consume(restored,'b')).ok,true);assert.equal((await consume(restored,'c')).ok,false);db.close();
});
test('uses only server key, strips upstream fields and enforces rate limit before upstream',async()=>{
 const {gate,db}=makeGate({IP_WINDOW_LIMIT:1});let calls=0;
 const upstream=async(url,options)=>{calls++;assert.equal(url,'https://api.deepseek.com/chat/completions');assert.equal(options.headers.Authorization,'Bearer fake-test-key');const p=JSON.parse(options.body);assert.equal(p.model,'deepseek-chat');assert.equal(p.max_tokens,1024);return Response.json({choices:[{message:{content:'你好'}}],secret_debug:'must-not-forward'});};
 const result=await handleRequest(req(),envWithGate(gate),upstream);assert.equal(result.status,200);assert.deepEqual(await result.json(),{choices:[{message:{role:'assistant',content:'你好'}}]});
 assert.equal((await handleRequest(req(),envWithGate(gate),upstream)).status,429);assert.equal(calls,1);db.close();
});
test('fails closed on oversized bodies, missing gate, invalid IP and provider errors',async()=>{
 const {gate,db}=makeGate();const env=envWithGate(gate);
 assert.equal((await handleRequest(req(),{DEEPSEEK_API_KEY:'fake'})).status,503);
 const noIp=new Request('https://test/v1/chat/completions',{method:'POST',body:JSON.stringify(valid)});assert.equal((await handleRequest(noIp,env)).status,403);
 assert.equal((await handleRequest(req({messages:[{role:'system',content:'小墨'+'x'.repeat(250000)}]}),env)).status,400);
 const failed=await handleRequest(req(),env,async()=>new Response('sensitive-upstream-body',{status:401}));assert.equal(failed.status,502);assert.ok(!(await failed.text()).includes('sensitive'));
 db.close();
});
