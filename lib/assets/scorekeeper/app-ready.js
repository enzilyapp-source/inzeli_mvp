(function () {
  'use strict';
  const config=window.InzeliConfig, people=config.people;
  function lockAndDecorate() {
    document.querySelectorAll('[data-mode]').forEach(el=>el.parentElement.classList.add('room-mode-fixed'));
    // The room owns identities, player count and solo/team assignment.
    document.querySelectorAll('[data-mode],#modeTeams,#modeSolo,#configurePlayersBtn,#setNameA,#setNameB,#playerCount,#kout-settings-open,#trix-settings-open').forEach(el=>{el.disabled=true;});
    document.querySelectorAll('#participant-names input,#playerNameSettings input,#player-count').forEach(el=>{el.disabled=true;});
    if(!config.editable) document.querySelectorAll('button,input,select').forEach(el=>{
      if(!el.closest('.trix-kingdoms') && el.id!=='trix-current')el.disabled=true;
    });
    document.querySelectorAll('.player-label,.teamName,.scoreboard-person>span,.trix-count-person,.trix-rank-row>label,.trix-kingdoms strong,.trix-person-options button').forEach(el=>{
      const name=el.childNodes[0]?.textContent?.trim();
      const person=people.find(p=>p.name===name);
      if(!person || el.querySelector('.room-avatar'))return;
      const badge=document.createElement('span');badge.className='room-avatar';badge.setAttribute('aria-hidden','true');
      badge.textContent=person.name.slice(0,1);
      if(person.avatar && /^(data:image\/(png|jpeg|jpg|webp);base64,|https:\/\/)/.test(person.avatar)){
        const img=document.createElement('img');img.alt='';img.referrerPolicy='no-referrer';img.src=person.avatar;
        img.onerror=()=>img.remove();badge.append(img);
      }
      el.prepend(badge);
    });
    if(config.teamMode) {
      for(const team of ['A','B']) {
        const labels=[...document.querySelectorAll(`label[for="score-${team}"],label[for="baloot-input-${team}"],#team${team} .teamName,#kout-score-name-${team}`)];
        for(const label of labels){
          if(label.querySelector('.room-team-members'))continue;
          const strip=document.createElement('span');strip.className='room-team-members';
          for(const person of people.filter(p=>p.team===team)){
            const member=document.createElement('span');member.className='room-team-member';
            const avatar=document.createElement('span');avatar.className='room-avatar';avatar.setAttribute('aria-hidden','true');avatar.textContent=Array.from(person.name)[0];
            if(person.avatar && /^(data:image\/(png|jpeg|jpg|webp);base64,|https:\/\/)/.test(person.avatar)){
              const image=document.createElement('img');image.alt='';image.src=person.avatar;image.referrerPolicy='no-referrer';image.onerror=()=>image.remove();avatar.append(image);
            }
            member.append(avatar,document.createTextNode(person.name));strip.append(member);
          }
          label.append(strip);
        }
      }
    }
    if(config.kind==='trix' && config.teamMode){
      const state=JSON.parse(window.InzeliExport()['qaed.trix.v1']);
      const totals=window.TrixScore.totals(state), teams={A:0,B:0};
      people.forEach((p,i)=>teams[p.team]+=totals[i]);
      let board=document.getElementById('room-team-totals');
      if(!board){board=document.createElement('div');board.id='room-team-totals';board.className='room-team-totals';document.querySelector('.game-heading').after(board);}
      const text=`الفريق A: ${teams.A}  ·  الفريق B: ${teams.B}`;
      if(board.textContent!==text)board.textContent=text;
      if(window.TrixScore.completed(state)){
        const name=teams.A===teams.B?'تعادل الفريقين':`الفائز: الفريق ${teams.A>teams.B?'A':'B'}`;
        const title=document.getElementById('trix-winner-name');if(title.textContent!==name)title.textContent=name;
      }
    }
  }
  let queued=false;
  const observer=new MutationObserver(()=>{
    if(queued)return;queued=true;
    requestAnimationFrame(()=>{queued=false;lockAndDecorate();});
  });
  observer.observe(document.body,{childList:true,subtree:true,characterData:true});
  window.InzeliDispose=()=>observer.disconnect();
  window.InzeliSetReadOnly=()=>{config.editable=false;lockAndDecorate();};
  lockAndDecorate();
  window.InzeliPublish();
  window.InzeliBridge?.postMessage(JSON.stringify({type:'ready'}));
})();
