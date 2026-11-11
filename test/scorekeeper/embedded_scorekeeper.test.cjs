const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');const {JSDOM}=require('jsdom');
const root=path.join(__dirname,'../../lib/assets/scorekeeper');
const pages={hand:'index.html',spita:'spita.html',kout:'kout.html',baloot:'baloot.html',trix:'trix.html',general:'general.html'};
function open(kind,{editable=true,teamMode=['kout','baloot'].includes(kind),storage={},count=4,oldEngine=false}={}){
 let html=fs.readFileSync(path.join(root,pages[kind]),'utf8');if(kind==='general')html=html.replace('p.players.slice(0, 8)','p.players.slice(0, window.InzeliConfig.people.length)').replaceAll('clampInt($("playerCount").value, 2, 8)','window.InzeliConfig.people.length');const dom=new JSDOM(html,{url:'https://score.inzeli.local/',runScripts:'outside-only',pretendToBeVisual:true});
 const w=dom.window,messages=[];w.InzeliConfig={kind,editable,teamMode,storage,people:Array.from({length:count},(_,i)=>({id:'user-'+i,name:['سالم','علي','حمد','محمد'][i]||'شخص '+i,avatar:null,team:i%2?'B':'A'}))};
 w.InzeliBridge={postMessage:text=>messages.push(JSON.parse(text))};
 const run=file=>w.eval(fs.readFileSync(path.join(root,file),'utf8'));
 if(oldEngine)w.Object.hasOwn=undefined;
 run('app-bridge.js');
 for(const match of html.matchAll(/<script defer src="([^"]+)"><\/script>/g))run(match[1]);
 for(const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g))w.eval(match[1]);
 run('app-ready.js');return {dom,w,messages,$:id=>w.document.getElementById(id),export:()=>w.InzeliExport()};
}
for(const kind of Object.keys(pages))test(kind+': seeded room names and round-trip work, spectators never publish changes',()=>{
 const host=open(kind);const payload=host.messages.find(m=>m.type==='snapshot');assert(payload,kind);assert(host.messages.some(m=>m.type==='ready'));
 assert.equal(Object.keys(payload.storage).length,1);
 const restored=open(kind,{storage:payload.storage});assert(!restored.$('storage-warning')||restored.$('storage-warning').hidden);
 const viewer=open(kind,{editable:false,storage:payload.storage});
 assert(viewer.messages.every(m=>m.type!=='snapshot'));
 for(const input of viewer.w.document.querySelectorAll('input'))assert(input.disabled);
 if(!['kout','baloot'].includes(kind))assert(host.w.document.body.textContent.includes('سالم'));
 host.w.InzeliDispose();host.dom.window.close();restored.w.InzeliDispose();restored.dom.window.close();viewer.w.InzeliDispose();viewer.dom.window.close();
});
test('individual Hand records real room members and preserves totals for viewer',()=>{
 const host=open('hand',{count:4});host.$('score-p1').value='-40';host.$('score-p1').dispatchEvent(new host.w.Event('input'));
 assert.equal(host.$('score-p4').value,'+200');host.$('register-round').click();
 const viewer=open('hand',{editable:false,storage:host.export()});assert(viewer.$('current-scores').textContent.includes('-40'));
 assert.equal(viewer.$('score-inputs').children.length,4);assert(viewer.$('score-inputs').textContent.includes('محمد'));
 host.w.InzeliDispose();host.dom.window.close();viewer.w.InzeliDispose();viewer.dom.window.close();
});
test('same display names are distinct participants, and input text is never interpreted as markup',()=>{
 const ui=open('hand');assert.equal(ui.$('score-inputs').children.length,4);
 const payload=JSON.parse(ui.export()['qaed.hand.v1']);payload.profiles.individual.participants[0].name='<img src=x onerror=alert(1)>';
 const restored=open('hand',{storage:{'qaed.hand.v1':JSON.stringify(payload)}});
 assert.equal(restored.w.document.querySelector('img[onerror]'),null);
 ui.w.InzeliDispose();ui.dom.window.close();restored.w.InzeliDispose();restored.dom.window.close();
});
test('destructive controls ask native confirmation before changing the ledger',()=>{
 const ui=open('baloot');ui.$('baloot-input-A').value='30';ui.$('baloot-input-A').dispatchEvent(new ui.w.Event('input'));
 ui.$('baloot-input-B').value='5';ui.$('baloot-input-B').dispatchEvent(new ui.w.Event('input'));ui.$('baloot-register').click();
 ui.$('baloot-new').click();assert.equal(ui.$('baloot-total-A').textContent,'30');
 assert(ui.messages.some(m=>m.type==='confirm'&&m.action==='baloot-new'));
 ui.w.InzeliConfirm('baloot-new');assert.equal(ui.$('baloot-total-A').textContent,'0');ui.w.InzeliDispose();ui.dom.window.close();
});

test('general supports every joined Uno player beyond the website picker limit',()=>{
 const ui=open('general',{count:10});assert.equal(ui.w.document.querySelectorAll('.soloInput').length,10);
 ui.$('settingsBtn').click();ui.$('targetPoints').value='500';ui.$('saveSettingsBtn').click();
 const saved=JSON.parse(ui.export()['jinjfa_score_v1']);assert.equal(saved.profiles.solo.players.length,10);assert.equal(saved.profiles.solo.target,500);
 ui.w.InzeliSetReadOnly();assert(ui.w.document.querySelector('.soloInput').disabled);
 ui.w.InzeliDispose();ui.dom.window.close();
});

test('older supported iOS WebViews can still choose Kout contracts',()=>{
 const ui=open('kout',{oldEngine:true});
 const choose=(field,value)=>ui.w.document.querySelector(`[data-kout-field="${field}"][data-kout-value="${value}"]`).click();
 choose('team','A');choose('contract','5');choose('outcome','win');ui.$('kout-register').click();
 assert.equal(ui.$('kout-score-A').textContent,'5');ui.w.InzeliDispose();ui.dom.window.close();
});
