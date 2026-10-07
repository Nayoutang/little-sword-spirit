const UPSTREAM = 'https://api.deepseek.com/chat/completions';
const MAX_BODY = 240000;
const MAX_CONTENT = 120000;
const MAX_REPLY = 200000;
const DAY = 86400000;
const WINDOW = 600000;
const allowedOrigins = new Set(['null']);

function response(payload, status = 200, extra = {}) {
  return new Response(JSON.stringify(payload), {status, headers: {'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store', ...extra}});
}
function failure(message, status, headers = {}) {
  return response({error:{message,type:'proxy_error'}}, status, headers);
}
export function validatePayload(input) {
  if (!input || !Array.isArray(input.messages) || input.messages.length < 1 || input.messages.length > 80) throw new Error('invalid_messages');
  let total = 0;
  const messages = input.messages.map(m => {
    if (!m || !['system','user','assistant'].includes(m.role) || typeof m.content !== 'string') throw new Error('invalid_message');
    total += m.content.length;
    return {role:m.role, content:m.content};
  });
  if (total > MAX_CONTENT || !messages.some(m=>m.role==='system' && m.content.includes('小墨'))) throw new Error('invalid_game_context');
  const result = {messages, stream:false, max_tokens:Math.min(1024, Math.max(32, Number.isFinite(input.max_tokens) ? Math.floor(input.max_tokens) : 768))};
  for (const name of ['temperature','frequency_penalty','presence_penalty']) {
    if (Number.isFinite(input[name])) result[name] = Math.min(2,Math.max(name==='temperature'?0:-2,input[name]));
  }
  if (input.response_format?.type === 'json_object') result.response_format = {type:'json_object'};
  return result;
}
async function readLimited(request, limit) {
  const reader = request.body?.getReader();
  if (!reader) return '';
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done,value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > limit) { await reader.cancel(); throw new Error('too_large'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk,offset); offset += chunk.length; }
  return new TextDecoder().decode(bytes);
}
export async function handleRequest(request, env, upstreamFetch = fetch) {
  const origin = request.headers.get('Origin') || '';
  const cors = origin && allowedOrigins.has(origin) ? {'Access-Control-Allow-Origin':origin,'Vary':'Origin','Access-Control-Allow-Headers':'Content-Type, X-Game-Client','Access-Control-Allow-Methods':'POST, GET, OPTIONS'} : {};
  if (origin && !allowedOrigins.has(origin)) return failure('Origin not allowed',403);
  const path = new URL(request.url).pathname;
  if (request.method === 'OPTIONS') return new Response(null,{status:204,headers:cors});
  if (path === '/health' && request.method === 'GET') return response({ok:true,service:'little-sword-spirit',configured:Boolean(env.DEEPSEEK_API_KEY)},200,cors);
  if (path !== '/v1/chat/completions') return failure('Not found',404,cors);
  if (request.method !== 'POST') return failure('Method not allowed',405,cors);
  if (!env.DEEPSEEK_API_KEY || !env.USAGE_GATE) return failure('AI service unavailable',503,cors);
  let payload;
  try { payload = validatePayload(JSON.parse(await readLimited(request,MAX_BODY))); }
  catch { return failure('Invalid or oversized game request',400,cors); }
  const ip = request.headers.get('CF-Connecting-IP');
  if (!ip) return failure('Client identity unavailable',403,cors);
  // 仅存储 IP 的哈希；所有 Worker 实例共用一个持久化计数器。
  const digest = await crypto.subtle.digest('SHA-256',new TextEncoder().encode(ip));
  const identity = Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
  let allowed;
  try {
    const gate = env.USAGE_GATE.get(env.USAGE_GATE.idFromName('public-usage'));
    const result = await gate.fetch(new Request('https://usage.internal/consume',{method:'POST',body:JSON.stringify({identity})}));
    allowed = await result.json();
    if (!result.ok) return failure('AI service temporarily unavailable',503,cors);
  } catch { return failure('AI service temporarily unavailable',503,cors); }
  if (!allowed.ok) return failure('Request quota exceeded; try later',429,{...cors,'Retry-After':String(allowed.retryAfter)});
  payload.model = env.MODEL_NAME || 'deepseek-chat';
  try {
    const upstream = await upstreamFetch(UPSTREAM,{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${env.DEEPSEEK_API_KEY}`},body:JSON.stringify(payload),signal:AbortSignal.timeout(25000)});
    if (!upstream.ok) { await upstream.body?.cancel(); return failure('AI provider temporarily unavailable',502,cors); }
    const data = JSON.parse(await readLimited(upstream,MAX_REPLY));
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || !content.trim()) return failure('AI provider returned no usable reply',502,cors);
    // 不透传上游错误、头部或诊断，仅返回游戏所需内容。
    return response({choices:[{message:{role:'assistant',content}}]},200,cors);
  } catch { return failure('AI request failed or timed out',502,cors); }
}
export default {fetch(request, env) { return handleRequest(request, env); }};

export class UsageGate {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    state.storage.sql.exec('CREATE TABLE IF NOT EXISTS quotas (id TEXT PRIMARY KEY, count INTEGER NOT NULL, expires INTEGER NOT NULL)');
  }
  async fetch(request) {
    const {identity} = await request.json();
    if (!/^[a-f0-9]{64}$/.test(identity || '')) return response({ok:false},400);
    const now = Date.now();
    const windowStart = Math.floor(now/WINDOW)*WINDOW;
    const dayStart = Math.floor(now/DAY)*DAY;
    const positive = (value,fallback)=>Number.isFinite(Number(value)) && Number(value)>0 ? Math.floor(Number(value)) : fallback;
    const buckets = [
      {id:`ip-window:${identity}:${windowStart}`,limit:positive(this.env.IP_WINDOW_LIMIT,60),expires:windowStart+WINDOW},
      {id:`ip-day:${identity}:${dayStart}`,limit:positive(this.env.IP_DAILY_LIMIT,400),expires:dayStart+DAY},
      {id:`global-day:${dayStart}`,limit:positive(this.env.GLOBAL_DAILY_LIMIT,5000),expires:dayStart+DAY},
    ];
    const result = this.state.storage.transactionSync(()=>{
      const sql = this.state.storage.sql;
      sql.exec('DELETE FROM quotas WHERE expires <= ?',now);
      for (const bucket of buckets) {
        const rows = sql.exec('SELECT count FROM quotas WHERE id = ?',bucket.id).toArray();
        if ((rows[0]?.count || 0) >= bucket.limit) return {ok:false,retryAfter:Math.max(1,Math.ceil((bucket.expires-now)/1000))};
      }
      for (const bucket of buckets) sql.exec('INSERT INTO quotas (id,count,expires) VALUES (?,1,?) ON CONFLICT(id) DO UPDATE SET count=count+1',bucket.id,bucket.expires);
      return {ok:true};
    });
    return response(result);
  }
}
