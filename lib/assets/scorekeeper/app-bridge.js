/* Native-only adapter. Core game engines below remain byte-for-byte website copies. */
(function () {
  'use strict';
  // iOS 15.0/WebViews may predate Object.hasOwn although the app supports them.
  if (!Object.hasOwn) Object.hasOwn=(object,key)=>Object.prototype.hasOwnProperty.call(object,key);
  const config = window.InzeliConfig;
  const keys = {general:'jinjfa_score_v1',hand:'qaed.hand.v1',spita:'qaed.spita.v1',kout:'qaed.kout.v1',baloot:'qaed.baloot.v1',trix:'qaed.trix.v1'};
  const key = keys[config.kind], values = {...config.storage};
  const mode = config.teamMode ? 'teams' : 'individual';
  function seed() {
    const people = config.people;
    if (config.kind === 'general') {
      const profile = () => ({target:100,nameA:'الفريق A',nameB:'الفريق B',scoreA:0,scoreB:0,rounds:[],
        players:people.map((p,i)=>({id:'p'+(i+1),name:p.name,score:0}))});
      return {mode:config.teamMode?'teams':'solo', profiles:{teams:profile(),solo:profile(),players:profile()}};
    }
    if (config.kind === 'hand' || config.kind === 'spita') {
      const H = config.kind === 'spita' ? window.SpitaScore : window.HandScore;
      const state = H.initialState(); state.mode = mode;
      state.profiles[mode] = H.profile(mode, config.teamMode ? 2 : people.length);
      state.profiles[mode].participants.forEach((p,i)=>{p.name=config.teamMode?'الفريق '+p.id:people[i].name;});
      return state;
    }
    if (config.kind === 'kout') return window.KoutScore.initialState();
    if (config.kind === 'baloot') return window.BalootScore.initialState();
    const state = window.TrixScore.initialState();
    state.players.forEach((p,i)=>{p.name=people[i].name;}); return state;
  }
  function refreshNames(value) {
    const state=JSON.parse(value), people=config.people;
    if(config.kind==='hand'||config.kind==='spita') {
      const p=state.profiles[mode];
      if(!config.teamMode)p.participants.forEach((person,i)=>{person.name=people[i]?.name||person.name;});
    } else if(config.kind==='trix')state.players.forEach((person,i)=>{person.name=people[i]?.name||person.name;});
    else if(config.kind==='general' && !config.teamMode) {
      state.profiles.solo.players.forEach((person,i)=>{person.name=people[i]?.name||person.name;});
    }
    return JSON.stringify(state);
  }
  if(values[key]) { try { values[key]=refreshNames(values[key]); } catch(_) { /* Engine reports corrupt saves without deleting them. */ } }
  let ready = false, lastSent = '';
  function publish() {
    if (!ready || !config.editable || !values[key]) return;
    const message = JSON.stringify({type:'snapshot',storage:{[key]:values[key]}});
    if(message !== lastSent) { lastSent = message; window.InzeliBridge?.postMessage(message); }
  }
  const storage = {
    getItem(k) { if(k === key && !values[k]) values[k] = JSON.stringify(seed()); return values[k] ?? null; },
    setItem(k,v) { values[k]=String(v); if(k===key) publish(); },
    removeItem(k) { delete values[k]; },
    clear() { delete values[key]; },
    key(i) { return Object.keys(values)[i] ?? null; },
    get length() { return Object.keys(values).length; },
  };
  Object.defineProperty(window,'localStorage',{value:storage, configurable:true});
  // No browser dialogs: Flutter handles them, including on Android WebView.
  window.confirm = message => {
    window.InzeliBridge?.postMessage(JSON.stringify({type:'confirm',message,action:window.InzeliLastAction||''}));
    return false;
  };
  window.InzeliConfirm = function(action) {
    const original=window.confirm; window.confirm=()=>true;
    try { document.getElementById(action)?.click(); } finally { window.confirm=original; }
  };
  document.addEventListener('click', event => {
    const button=event.target.closest('button');
    if(button) window.InzeliLastAction=button.id;
  },true);
  window.InzeliPublish = () => { ready=true; publish(); };
  window.InzeliExport = () => ({[key]:values[key]});
})();
