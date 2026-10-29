const http=require('http'),https=require('https'),fs=require('fs'),crypto=require('crypto');
const ROOT=process.argv[2],PORT=+(process.argv[3]||20129);
const HOME=process.env.HOME,S=HOME+'/.c-state',M=S+'/m',up=new URL(ROOT);
const W=!process.env.C_NOWRITE;
let KEY='';try{const e=JSON.parse(fs.readFileSync(HOME+'/.claude/settings.json','utf8')).env||{};KEY=e.ANTHROPIC_AUTH_TOKEN||e.ANTHROPIC_API_KEY||''}catch(e){}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
try{if(W&&fs.statSync(S+'/router.log').size>300000)fs.writeFileSync(S+'/router.log','');}catch(e){}
const log=s=>{if(W)fs.appendFile(S+'/router.log',new Date().toTimeString().slice(0,8)+' '+s+'\n',()=>{});};
process.on('uncaughtException',e=>log('err '+e.message));
process.on('unhandledRejection',e=>log('rej '+(e&&e.message)));
let cache={t:0,l:[]},prev=null;
function load(){
  if(Date.now()-cache.t<2000)return cache.l;
  const o=[];
  try{for(const f of fs.readdirSync(M)){if(!f.endsWith('.r'))continue;
    const p=fs.readFileSync(M+'/'+f,'utf8').trim().split('\t');
    if(p[0]==='PASS')o.push({m:p[2],lat:+p[3]||9999});}}catch(e){}
  cache={t:Date.now(),l:o};
  const cur=new Set(o.map(x=>x.m));
  if(prev){for(const m of cur)if(!prev.has(m))log('+PASS '+m);for(const m of prev)if(!cur.has(m))log('-DROP '+m);}
  prev=cur;return o;
}
const SM=/(^|[-_\/:.])(mini|nano|lite|flash|haiku|small|tiny|instant)([-_\/:.]|$)/i;
const SZ=/[-_\/:]([1-9]|1[0-9]|2[0-9]|3[0-2])b([-_.:]|$)/i;
const ST=/opus|gpt-?5|gpt-4\.1|(^|[-_\/])o[34]([-_]|$)|gemini[-\w.]*(2\.5|3)[-\w.]*pro|sonnet|deepseek[-\w.]*(r1|v3|v4)|qwen3?[-\w.]*(coder|235b|480b|max|plus)|kimi[-\w.]*k2|glm[-\w.]*(4\.[5-9]|5)|405b|llama[-\w.]*4|mistral[-\w.]*large|grok[-\w.]*[34]|minimax[-\w.]*m2|gpt-oss-120b|codex/i;
const str=m=>SM.test(m)?1:ST.test(m)?3:SZ.test(m)?1:2;
const TN=['','fast','mid','best'];
function loadAgents(){
  const base=HOME+'/.claude/plugins/cache/ecc/ecc';let d=null;
  try{const v=fs.readdirSync(base).sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));if(v.length)d=base+'/'+v[v.length-1]+'/agents';}catch(e){}
  if(!d||!fs.existsSync(d))d=HOME+'/.claude/plugins/marketplaces/ecc/agents';
  const out=[];
  try{for(const f of fs.readdirSync(d)){if(!f.endsWith('.md'))continue;
    const t=fs.readFileSync(d+'/'+f,'utf8');
    const m=t.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);if(!m)continue;
    const g=k=>{const x=m[1].match(new RegExp('^'+k+':\\s*(.*)$','m'));return x?x[1].replace(/^["']|["']\s*$/g,'').trim():'';};
    const name=g('name');if(!name)continue;
    out.push({name,desc:g('description'),pin:g('model'),body:m[2]});
  }}catch(e){}
  // har agent ki apni unique line (common boilerplate jaise 'Prompt Defense Baseline' skip) = pehchaan
  const cnt=new Map(),lines=a=>a.body.split('\n').map(l=>l.replace(/\s+/g,' ').trim()).filter(l=>l.length>=30);
  for(const a of out)for(const l of new Set(lines(a)))cnt.set(l,(cnt.get(l)||0)+1);
  for(const a of out){const u=lines(a).find(l=>cnt.get(l)===1);a.snip=u?u.slice(0,140):'';delete a.body;}
  return out;
}
let AG=[],agT=0;
function agents(){if(!agT||Date.now()-agT>600000){AG=loadAgents();agT=Date.now();log('agents loaded: '+AG.length);}return AG;}
const sysText=j=>{const s=j.system;if(!s)return'';if(typeof s==='string')return s;if(Array.isArray(s))return s.map(x=>x&&x.text||'').join('\n');return'';};
const DEEP=/architect|planner|planning|security|review|database|performance|orchestrat|principal|migration|reasoning|design|audit|vulnerab/i;
const LIGHT=/\bdocs?\b|documentation|readme|changelog|summariz|formatt|lint|catalog|explor/i;
const CODE=/code|test|build|refactor|tdd|e2e|debug|fix|implement|review/i;
const CODEY=/coder|codex|qwen|deepseek|glm|kimi|claude|gpt|minimax/i;
function profile(j,want){
  const sys=sysText(j).replace(/\s+/g,' ');
  let ag=null;
  for(const a of agents()){if(a.snip.length>30&&sys.includes(a.snip)){ag=a;break;}}
  if(ag){
    let need={haiku:1,sonnet:2,opus:3}[(ag.pin||'').toLowerCase()]||2;
    const t=ag.name+' '+ag.desc;
    if(DEEP.test(t))need++;else if(LIGHT.test(t))need--;
    need=Math.max(1,Math.min(3,need));
    return {need,key:ag.name,codey:CODE.test(t)};
  }
  if(/^c-fast$|haiku/i.test(want))return {need:1,key:'quick',codey:false};
  if(/^c-mid$|sonnet/i.test(want))return {need:2,key:'main',codey:true};
  return {need:3,key:'main',codey:true};
}
const recent=[],lastKey={},stats={},AGS={};
const others=(m,k)=>{const now=Date.now();let c=0;for(const r of recent)if(r.m===m&&r.k!==k&&now-r.t<20000)c++;return c;};
function score(x,p){
  const s=str(x.m);
  const fit=p.need===3?[0,0,15,30][s]:p.need===2?[0,8,30,22][s]:[0,30,20,10][s];
  let sc=fit-Math.min(x.lat/400,15)+(p.codey&&CODEY.test(x.m)?4:0);
  sc-=Math.min(others(x.m,p.key)*4,12);
  if(lastKey[p.key]===x.m)sc+=p.key==='main'?15:8;
  const st=stats[x.m];if(st&&st.n>=3&&st.e>st.n*0.3)sc-=10;
  return sc+Math.random()*3;
}
function pick(p,want){
  const l=load().map(x=>({m:x.m,sc:score(x,p)})).sort((a,b)=>b.sc-a.sc).map(x=>x.m);
  const k=l.indexOf(want);if(k>0){l.splice(k,1);l.unshift(want);}
  return l;
}
async function cands(p,want){
  for(let i=0;i<180;i++){const l=pick(p,want);if(l.length)return l;await sleep(1000);}
  return [];
}
function mark(m,why){
  const h=crypto.createHash('md5').update(m).digest('hex').slice(0,16);
  why=String(why).replace(/[\t\r\n]+/g,' ').slice(0,100);
  try{fs.writeFileSync(M+'/'+h+'.rt.tmp','FAIL\t'+Math.floor(Date.now()/1000)+'\t'+m+'\t0\truntime: '+why+'\n');fs.renameSync(M+'/'+h+'.rt.tmp',M+'/'+h+'.r');}catch(e){}
  (stats[m]||(stats[m]={n:0,e:0,ms:0,t:0})).e++;
  cache.t=0;log('FAIL '+m+' ('+why+')');
}
function ok(m,p,ms){
  const now=Date.now();
  const st=stats[m]||(stats[m]={n:0,e:0,ms:0,t:0});st.n++;st.t=now;
  const a=AGS[p.key]||(AGS[p.key]={n:0});a.n++;a.m=m;a.t=now;
  if(lastKey[p.key]!==m){log('use '+p.key+' -> '+m+' ('+TN[p.need]+')');lastKey[p.key]=m;}
  if(W)fs.writeFile(S+'/active',p.key+' -> '+m,()=>{});
}
function dump(){
  const models={};
  for(const x of load()){const st=stats[x.m]||{};models[x.m]={s:str(x.m),lat:x.lat,n:st.n||0,e:st.e||0,t:st.t||0};}
  return {t:Date.now(),models,agents:AGS};
}
if(W)setInterval(()=>{try{fs.writeFileSync(S+'/stats.tmp',JSON.stringify(dump()));fs.renameSync(S+'/stats.tmp',S+'/stats.json');}catch(e){}},3000);
function fwd(method,p,h,b){return new Promise((res,rej)=>{
  const lib=up.protocol==='https:'?https:http;
  const r=lib.request({hostname:up.hostname,port:up.port||(up.protocol==='https:'?443:80),path:p,method,headers:h,timeout:120000},res);
  r.on('timeout',()=>r.destroy(new Error('timeout')));r.on('error',rej);r.end(b);});}
async function fwdR(method,p,h,b){for(let i=0;;i++){try{return await fwd(method,p,h,b);}catch(e){if(e.code==='ECONNREFUSED'&&i<45){await sleep(2000);continue;}throw e;}}}
const readAll=s=>new Promise(r=>{const c=[];s.on('data',d=>c.push(d));s.on('end',()=>r(Buffer.concat(c)));s.on('error',()=>r(Buffer.concat(c)));});
async function handle(req,cres,body){
  const u0=req.url.split('?')[0];
  if(u0==='/__c/health'){cres.writeHead(200);return cres.end('ok '+load().length);}
  if(u0==='/__c/models'){cres.writeHead(200,{'content-type':'application/json'});return cres.end(JSON.stringify(load().map(x=>({model:x.m,tier:TN[str(x.m)],ms:x.lat}))));}
  if(u0==='/__c/stats'){cres.writeHead(200,{'content-type':'application/json'});return cres.end(JSON.stringify(dump()));}
  const hdr={'content-type':'application/json','anthropic-version':req.headers['anthropic-version']||'2023-06-01','accept-encoding':'identity'};
  if(KEY){hdr['x-api-key']=KEY;hdr.authorization='Bearer '+KEY;}
  let j=null;if(req.method==='POST'&&body.length){try{j=JSON.parse(body);}catch(e){}}
  const isCnt=!!j&&/count_tokens/.test(req.url),isMsg=!!j&&/\/v1\/messages(\?|$)/.test(req.url);
  if(!isCnt&&!isMsg){
    const u=await fwdR(req.method,req.url,Object.assign({},hdr,{'content-length':body.length}),body);
    cres.writeHead(u.statusCode,u.headers);return u.pipe(cres);
  }
  const want=String(j.model||'');
  const p=profile(j,want);
  delete j.thinking;delete j.context_management;
  const list=await cands(p,want);let last=null;
  for(const m of list.slice(0,8)){
    j.model=m;const b=Buffer.from(JSON.stringify(j));
    recent.push({m,k:p.key,t:Date.now()});while(recent.length>300)recent.shift();
    const t0=Date.now();let u;
    try{u=await fwdR('POST',req.url,Object.assign({},hdr,{'content-length':b.length}),b);}
    catch(e){if(!isCnt)mark(m,e.message);continue;}
    const sc=u.statusCode;
    if(sc>=400){
      const eb=await readAll(u);last={sc,eb,ct:u.headers['content-type']};
      if(!isCnt&&![400,413,422].includes(sc))mark(m,'http '+sc+' '+eb.toString());
      continue;
    }
    if(/event-stream/.test(u.headers['content-type']||'')){
      const first=await new Promise(r=>{u.once('data',c=>{u.pause();r(c);});u.once('end',()=>r(null));u.once('error',()=>r(null));});
      const t=first?first.toString('utf8',0,600):'';
      if(!first||/^\s*(event:\s*error|data:\s*\{\s*"type"\s*:\s*"error")/.test(t)){mark(m,'stream '+t);u.destroy();continue;}
      if(!isCnt)ok(m,p,Date.now()-t0);
      cres.writeHead(200,u.headers);cres.write(first);cres.on('close',()=>u.destroy());u.pipe(cres);u.resume();return;
    }
    const eb=await readAll(u);let jj=null;try{jj=JSON.parse(eb);}catch(e){}
    if(jj&&jj.type==='error'){if(!isCnt)mark(m,'body '+eb.toString());continue;}
    if(!isCnt)ok(m,p,Date.now()-t0);
    cres.writeHead(sc,Object.assign({},u.headers,{'content-length':eb.length}));return cres.end(eb);
  }
  if(isCnt){cres.writeHead(200,{'content-type':'application/json'});return cres.end(JSON.stringify({input_tokens:Math.ceil(body.length/4)}));}
  if(last&&list.length&&last.sc!==529){cres.writeHead(last.sc,{'content-type':last.ct||'application/json'});return cres.end(last.eb);}
  cres.writeHead(529,{'content-type':'application/json'});
  cres.end(JSON.stringify({type:'error',error:{type:'overloaded_error',message:'router: abhi koi PASS model available nahi (tester retest kar raha hai)'}}));
}
const server=http.createServer((req,cres)=>{
  const c=[];req.on('data',d=>c.push(d));
  req.on('end',()=>handle(req,cres,Buffer.concat(c)).catch(e=>{
    if(!cres.headersSent)cres.writeHead(502,{'content-type':'application/json'});
    cres.end(JSON.stringify({type:'error',error:{type:'api_error',message:'router: '+e.message}}));}));
});
server.on('error',e=>{if(e.code==='EADDRINUSE')process.exit(0);console.error(e);process.exit(1);});
server.listen(PORT,'127.0.0.1',()=>log('smart router up on '+PORT+' -> '+ROOT));
