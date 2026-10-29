// c Office: localhost par 3D office dashboard (koi dependency nahi). Sirf 127.0.0.1 par sunta hai.
const http = require('http'), fs = require('fs');
const PORT = +(process.argv[2] || 20130);
const ROOT = (process.argv[3] || 'http://localhost:20128').replace(/\/+$/, '');
const HOME = process.env.HOME, S = HOME + '/.c-state', RP = +(process.env.C_ROUTER_PORT || 20129);
const here = __dirname;
const rd = (f, d = '') => { try { return fs.readFileSync(f, 'utf8'); } catch (e) { return d; } };
const alive = f => { try { process.kill(+rd(f).trim(), 0); return true; } catch (e) { return false; } };
const ping = (url, t = 900) => new Promise(r => {
  const q = http.get(url, res => { res.resume(); r(res.statusCode); });
  q.setTimeout(t, () => { q.destroy(); r(0); }); q.on('error', () => r(0));
});

let eccC = { t: 0, l: [] };
function ecc() {
  if (Date.now() - eccC.t < 60000) return eccC.l;
  const base = HOME + '/.claude/plugins/cache/ecc/ecc'; let d = null;
  try { const v = fs.readdirSync(base).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })); if (v.length) d = base + '/' + v[v.length - 1] + '/agents'; } catch (e) {}
  if (!d || !fs.existsSync(d)) d = HOME + '/.claude/plugins/marketplaces/ecc/agents';
  const out = [];
  try {
    for (const f of fs.readdirSync(d)) {
      if (!f.endsWith('.md')) continue;
      const m = fs.readFileSync(d + '/' + f, 'utf8').match(/^---\r?\n([\s\S]*?)\r?\n---/); if (!m) continue;
      const g = k => { const x = m[1].match(new RegExp('^' + k + ':\\s*(.*)$', 'm')); return x ? x[1].replace(/^["']|["']\s*$/g, '').trim() : ''; };
      const name = g('name'); if (name) out.push({ name, desc: g('description').slice(0, 180), pin: g('model') });
    }
  } catch (e) {}
  eccC = { t: Date.now(), l: out }; return out;
}

let svc = { t: 0, v: {} };
async function services() {
  if (Date.now() - svc.t < 2500) return svc.v;
  const [o, r] = await Promise.all([ping(ROOT + '/v1/models'), ping('http://127.0.0.1:' + RP + '/__c/health')]);
  svc = { t: Date.now(), v: { omniroute: o > 0, router: r === 200, tester: alive(S + '/tester.pid'), health: alive(S + '/health.pid') } };
  return svc.v;
}

async function state() {
  const now = Date.now();
  let st = {}; try { st = JSON.parse(rd(S + '/stats.json', '{}')); } catch (e) {}
  const ags = st.agents || {}, seen = new Set(), list = [];
  const add = (name, desc, pin, role) => {
    if (seen.has(name)) return; seen.add(name);
    const s = ags[name]; const ago = s && s.t ? now - s.t : null;
    let status = 'standby';
    if (ago !== null) status = ago < 20000 ? 'working' : ago < 300000 ? 'idle' : 'rest';
    list.push({ name, role: role || '', desc: desc || '', pin: pin || '', status, model: s ? s.m : '', n: s ? s.n : 0, ago: ago === null ? null : Math.round(ago / 1000) });
  };
  add('main', 'Aapka main Claude Code session', '', 'lead');
  add('quick', 'Chhote/fast kaam (haiku-type calls)', '', 'lead');
  for (const a of ecc()) add(a.name, a.desc, a.pin);
  for (const k of Object.keys(ags)) add(k, '', '');
  const models = Object.entries(st.models || {}).map(([m, v]) => ({ m, tier: ['', 'fast', 'mid', 'best'][v.s] || 'mid', lat: v.lat || 0, n: v.n || 0, e: v.e || 0, live: v.t ? now - v.t < 30000 : false }))
    .sort((a, b) => b.n - a.n || a.lat - b.lat);
  const ev = rd(S + '/router.log').trim().split('\n').slice(-10);
  return {
    t: now, svc: await services(), agents: list, models,
    status: rd(S + '/status').trim(), active: rd(S + '/active').trim(), tiers: rd(S + '/tiers.txt').trim(),
    events: ev, omni_url: ROOT, eccPlugin: /plug=true/.test(rd(S + '/health.txt')), eccAgents: ecc().length,
  };
}

http.createServer(async (req, res) => {
  const u = req.url.split('?')[0];
  try {
    if (u === '/__ok') { res.writeHead(200); return res.end('ok'); }
    if (u === '/api/state') { res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' }); return res.end(JSON.stringify(await state())); }
    if (u === '/' || u === '/m' || u === '/d') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      const v = u === '/m' ? 'm' : u === '/d' ? 'd' : '';
      return res.end(rd(here + '/office.html').replace('__VIEW__', v));
    }
    res.writeHead(404); res.end('not found');
  } catch (e) { res.writeHead(500); res.end('err'); }
}).on('error', e => { if (e.code === 'EADDRINUSE') process.exit(0); console.error(e); process.exit(1); })
  .listen(PORT, '127.0.0.1', () => console.log('c office on http://localhost:' + PORT));
