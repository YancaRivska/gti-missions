/* Secondary screens are loaded on demand. No global user-data cache. */
const page=(title,body)=>{app.innerHTML=shell(`<header class="page-head"><div><button class="back-link" data-nav="profile">← Perfil</button><h1>${esc(title)}</h1></div></header>${body}`,'profile');bindNav();};
const notice=(element,error)=>{element.textContent=friendly(error);};
const date=value=>new Date(value.includes('T')?value:value+'T12:00:00').toLocaleDateString('pt-BR');
const buttons='<div class="profile-actions"><button class="secondary" data-nav="members">Comunidade</button><button class="secondary" data-nav="monthly">Ranking mensal</button></div>';

export async function renderProduct(view,player,url){
 if(view==='public-notes')return renderPublicNotes(url.searchParams.get('username'));
 if(view==='notes')return renderNotes(player);
 if(view==='privacy-settings')return renderPrivacy(player);
 if(view==='members'||view==='monthly')return renderMembers(view);
 if(view==='member')return renderMember(url.searchParams.get('username'));
 if(view==='collection')return renderCollection(player,url);
 if(view==='seasons')return renderSeasons(player,url);
}
async function renderNotes(player){
 page('Meu Diário',`<form id="noteForm" class="settings-card"><label>Título (opcional)<input name="title" maxlength="100"></label><label>O que você quer guardar?<textarea name="content" maxlength="3000" rows="6" required></textarea></label><label>Visibilidade<select name="visibility"><option value="private">Só eu</option><option value="public">Pública no meu perfil</option></select></label><p>Uma nota pública só aparece se seu perfil e suas notas estiverem visíveis para a comunidade.</p><button class="primary">Salvar nota</button><button type="button" class="secondary" id="cancelEdit" hidden>Cancelar edição</button><p id="noteMsg" role="status"></p></form><section id="notesList" class="mission-link-list"></section><button class="secondary full" id="moreNotes">Ver mais notas</button>`);
 const form=document.getElementById('noteForm'),list=document.getElementById('notesList'),more=document.getElementById('moreNotes'),msg=document.getElementById('noteMsg');
 let cursor=null,editing=null,rows=[];
 const load=async(reset=false)=>{
  more.disabled=true;
  try{
   if(reset){cursor=null;rows=[];list.innerHTML='';}
   const filter=cursor?`&or=(created_at.lt.${encodeURIComponent(cursor.created_at)},and(created_at.eq.${encodeURIComponent(cursor.created_at)},id.lt.${cursor.id}))`:'';
   const next=await request(`/rest/v1/gti_missions_notes?user_id=eq.${player.u.id}&select=id,title,content,visibility,created_at&order=created_at.desc,id.desc&limit=10${filter}`);
   rows.push(...next);cursor=next.at(-1)||cursor;
   list.innerHTML=rows.map(n=>`<article class="journal-note"><div><small>${date(n.created_at)} • ${n.visibility==='private'?'Só eu':'Pública'}</small><h2>${esc(n.title||'Nota')}</h2><p class="note-content">${esc(n.content)}</p><button class="secondary" data-edit="${n.id}">Editar</button> <button class="danger" data-delete="${n.id}">Excluir</button></div></article>`).join('')||'<p>Seu diário começa com a primeira nota.</p>';
   more.hidden=next.length<10;
   list.querySelectorAll('[data-edit]').forEach(b=>b.onclick=()=>{const n=rows.find(x=>x.id===b.dataset.edit);editing=n.id;for(const key of ['title','content','visibility'])form.elements[key].value=n[key];document.getElementById('cancelEdit').hidden=false;form.elements.content.focus();form.scrollIntoView({block:'start'});});
   list.querySelectorAll('[data-delete]').forEach(b=>b.onclick=async()=>{if(!confirm('Excluir esta nota?'))return;b.disabled=true;try{await request(`/rest/v1/gti_missions_notes?id=eq.${b.dataset.delete}`,{method:'DELETE'});if(editing===b.dataset.delete)resetForm();await load(true);}catch(e){notice(msg,e);b.disabled=false;}});
  }catch(e){notice(msg,e);}finally{more.disabled=false;}
 };
 function resetForm(){editing=null;form.reset();document.getElementById('cancelEdit').hidden=true;}
 document.getElementById('cancelEdit').onclick=resetForm;
 form.onsubmit=async e=>{e.preventDefault();const b=form.querySelector('button');b.disabled=true;try{const body={title:form.elements.title.value.trim(),content:form.elements.content.value.trim(),visibility:form.elements.visibility.value};await request('/rest/v1/gti_missions_notes'+(editing?'?id=eq.'+editing:''),{method:editing?'PATCH':'POST',body});resetForm();msg.textContent='Nota salva.';await load(true);}catch(error){notice(msg,error);}finally{b.disabled=false;}};
 more.onclick=()=>load();await load();
}
async function renderPrivacy(player){
 const p=player.p;
 page('Privacidade e minha missão',`<form id="privacyForm" class="settings-card"><label>Minha missão<input name="tagline" maxlength="120" value="${esc(p.tagline||'')}" placeholder="Criando constância antes de buscar perfeição."></label><label>Meu perfil<select name="profile_visibility"><option value="community" ${p.profile_visibility==='community'?'selected':''}>Comunidade</option><option value="private" ${p.profile_visibility==='private'?'selected':''}>Privado</option></select></label>${[['show_progress','Mostrar progresso'],['show_badges','Mostrar emblemas'],['show_notes','Mostrar notas públicas'],['show_history','Mostrar histórico']].map(([key,label])=>`<label class="check-row"><input type="checkbox" name="${key}" ${p[key]?'checked':''}><span>${label}</span></label>`).join('')}<p>Notas privadas continuam visíveis somente para você. Um perfil privado não aparece na descoberta nem no ranking.</p><button class="primary">Salvar preferências</button><p role="status" id="privacyMsg"></p></form>`);
 const form=document.getElementById('privacyForm');form.onsubmit=async e=>{e.preventDefault();const b=form.querySelector('button'),body={tagline:form.elements.tagline.value.trim(),profile_visibility:form.elements.profile_visibility.value};for(const k of ['show_progress','show_badges','show_notes','show_history'])body[k]=form.elements[k].checked;b.disabled=true;try{await request(`/rest/v1/gti_missions_profiles?user_id=eq.${player.u.id}`,{method:'PATCH',body});profileRequest=null;document.getElementById('privacyMsg').textContent='Preferências salvas.';}catch(error){notice(document.getElementById('privacyMsg'),error);}finally{b.disabled=false;}};
}
async function renderMembers(view){
 const ranking=view==='monthly';
 page(ranking?'Ranking mensal':'Comunidade',`${buttons}${ranking?'':`<form id="searchMembers"><label>Buscar pelo nome<input name="search" maxlength="60" type="search"></label><button class="secondary">Buscar</button></form>`}<section class="league-list" id="memberList"></section><p role="status" id="memberMsg"></p><button class="secondary full" id="moreMembers">Ver mais</button>`);
 const list=document.getElementById('memberList'),more=document.getElementById('moreMembers');let cursor='',offset=0,search='',busy=false;
 async function load(reset=false){if(busy)return;busy=true;more.disabled=true;try{if(reset){cursor='';offset=0;list.innerHTML='';}const rows=await rpc(ranking?'gti_missions_ranking':'gti_missions_members',ranking?{p_offset:offset,p_limit:20}:{p_search:search,p_after:cursor,p_limit:20});offset+=rows.length;cursor=rows.at(-1)?.username||cursor;list.insertAdjacentHTML('beforeend',rows.map(r=>`<article><strong>${ranking?'#'+r.rank:''}</strong><div class="league-user">${avatarFallback(r.display_name,'small')}<div><button class="link-btn" data-member="${esc(r.username)}">${esc(r.display_name)}</button><small>@${esc(r.username)}</small></div></div>${ranking?`<span>${fmt(r.xp)} XP</span>`:''}</article>`).join(''));if(!list.children.length)list.innerHTML='<p>Nenhum participante encontrado.</p>';more.hidden=rows.length<20;list.querySelectorAll('[data-member]').forEach(b=>b.onclick=()=>nav('member',false,{username:b.dataset.member}));}catch(error){notice(document.getElementById('memberMsg'),error);}finally{busy=false;more.disabled=false;}}
 if(!ranking)document.getElementById('searchMembers').onsubmit=e=>{e.preventDefault();search=e.target.elements.search.value.trim();load(true);};more.onclick=()=>load();await load();
}
async function renderMember(username){
 const p=await rpc('gti_missions_member',{p_username:username||''});
 if(!p){page('Perfil indisponível','<p>Este perfil é privado ou não foi encontrado.</p>'+buttons);return;}
 page(p.display_name,`<section class="member-hero game-panel">${await avatarHtml(p.avatar_path,p.display_name)}<div><small>EXPLORADOR GTI</small><h2>${esc(p.display_name)}</h2><p>@${esc(p.username)}</p></div><p class="member-message">${esc(p.tagline||'Cada ação real constrói um futuro maior.')}</p><strong>Nível ${p.level} · ${fmt(p.total_xp)} XP</strong></section>${p.challenges?`<section class="game-panel"><h2>Mundos ativos</h2><div class="profile-challenge-grid">${p.challenges.map(c=>`<article class="active"><b>${esc(c.name)}</b>${c.days!==undefined?`<small>${fmt(c.days)} dias neste mês</small>`:''}</article>`).join('')||'<p>Nenhum desafio ativo.</p>'}</div></section>`:'<p>Este participante mantém o progresso privado.</p>'}<nav class="profile-actions" aria-label="Mais sobre este participante">${p.badges?'<button class="secondary" id="memberCollection">Selos</button>':''}${p.notes?'<button class="secondary" id="allPublicNotes">Notas públicas</button>':''}${p.show_history?'<button class="secondary" id="memberHistory">Temporadas</button>':''}</nav>${buttons}`);
 if(p.notes)document.getElementById('allPublicNotes').onclick=()=>nav('public-notes',false,{username:p.username});
 if(p.badges)document.getElementById('memberCollection').onclick=()=>nav('collection',false,{username:p.username});
 if(p.show_history)document.getElementById('memberHistory').onclick=()=>nav('seasons',false,{username:p.username});
}
async function renderCollection(player,url){
 const type=['tech','rat-tech'].includes(url.searchParams.get('type'))?'tech':'aqua',username=url.searchParams.get('username');
 const badges=await rpc('gti_missions_collection',{p_type:type,p_username:username});
 page('Conquistas',`<nav class="world-tabs"><button data-type="aqua" class="${type==='aqua'?'active':''}">Missão Água</button><button data-type="tech" class="${type==='tech'?'active':''}">RAT Tech</button></nav>${!username?'<div class="profile-actions"><button class="secondary" data-legacy="reading">Leitura</button><button class="secondary" data-legacy="screen-free">Sem Tela</button><button class="secondary" data-legacy="global">Conquistas gerais</button></div>':''}<section class="achievement-summary"><div class="achievement-mascots"><img src="/assets/challenges/${type==='aqua'?'aquaxp/chalote-aquaxp-v1.webp':'rat-tech/chalote-rat-tech-v1.webp'}" alt="Chalote celebrando conquistas" width="720" height="960"></div><div><b>${badges.filter(b=>b.state==='unlocked').length} / ${badges.length} conquistados</b></div></section><section class="achievement-grid-v3">${badges.map(b=>`<article class="achievement-tile ${b.state==='unlocked'?'unlocked':'locked'}"><span>${esc(b.icon)}</span><div><b>${esc(b.name)}</b><small>${esc(b.description)}</small>${b.state==='unlocked'&&!username?`<button class="secondary" data-share="${esc(b.id)}">Compartilhar</button>`:`<small>${b.state==='secret'?'Secreto':b.state==='locked'?'Bloqueado':'Conquistado'}</small>`}</div></article>`).join('')||'<p>Coleção indisponível.</p>'}</section><p role="status" id="shareMsg"></p>`);
 document.querySelectorAll('[data-legacy]').forEach(b=>b.onclick=()=>nav('achievements',false,{type:b.dataset.legacy}));
 document.querySelectorAll('[data-type]').forEach(b=>b.onclick=()=>nav('collection',false,{type:b.dataset.type,...(username?{username}:{})}));
 document.querySelectorAll('[data-share]').forEach(b=>b.onclick=()=>shareDialog(badges.find(x=>x.id===b.dataset.share),player.p));
}
async function renderSeasons(player,url){
 const username=url.searchParams.get('username'),current=username?null:await rpc('gti_missions_current_season'),admin=!username&&await isAdmin();
 page('Temporadas',`${current?`<section class="settings-card season-cover"><small>TEMPORADA</small><h2>${esc(current.name)}</h2><p>${date(current.start_date)} → ${date(current.end_date)}</p><p>${current.joined?'Você participa desta temporada.':'Sua próxima missão começa aqui.'}</p>${!current.joined?`<form id="joinSeason">${current.requires_code?'<label>Código de participação<input name="code" maxlength="80" required autocomplete="off"></label>':''}<button class="primary">Entrar na temporada</button></form>`:''}<p id="seasonMsg" role="status"></p></section>`:''}${admin?`<form class="settings-card" id="adminSeason"><h2>Configurar temporada</h2><label>Mês<input name="month" type="month" required></label><label>Código de participação<input name="code" minlength="6" maxlength="80" autocomplete="off" placeholder="Vazio: participação sem código"></label><p>O código fica protegido no banco. Participantes já inscritos mantêm o acesso.</p><button class="primary">Salvar temporada</button><p id="adminSeasonMsg" role="status"></p></form>`:''}<h2>Histórico</h2><section id="seasonHistory" class="mission-link-list"></section><button class="secondary full" id="moreSeasons">Ver mais temporadas</button>`);
 if(current&&!current.joined)document.getElementById('joinSeason').onsubmit=async e=>{e.preventDefault();const b=e.target.querySelector('button');b.disabled=true;try{const ok=await rpc('gti_missions_join_season',{p_code:e.target.elements.code?.value||''});if(!ok){document.getElementById('seasonMsg').textContent='Código inválido ou limite de tentativas atingido. Confira o código; após várias tentativas, aguarde 15 minutos.';return;}await renderSeasons(player,url);}catch(error){notice(document.getElementById('seasonMsg'),error);}finally{b.disabled=false;}};
 if(admin)document.getElementById('adminSeason').onsubmit=async e=>{e.preventDefault();const b=e.target.querySelector('button');b.disabled=true;try{await rpc('gti_missions_admin_season',{p_month:e.target.elements.month.value+'-01',p_code:e.target.elements.code.value.trim()});e.target.elements.code.value='';document.getElementById('adminSeasonMsg').textContent='Temporada configurada.';}catch(error){notice(document.getElementById('adminSeasonMsg'),error);}finally{b.disabled=false;}};
 let before=null;const more=document.getElementById('moreSeasons');async function load(){more.disabled=true;try{const rows=await rpc('gti_missions_history',{p_before:before,p_username:username});document.getElementById('seasonHistory').insertAdjacentHTML('beforeend',rows.map(s=>`<article><div><b>${esc(s.name)} ${s.status==='active'?'🔥':'✓'}</b><p>${fmt(s.xp)} XP • Água: ${s.water_days} dias • Treinos: ${s.workout_days} dias</p></div></article>`).join(''));before=rows.at(-1)?.start_date||before;more.hidden=rows.length<12;if(!before)document.getElementById('seasonHistory').textContent='As temporadas em que você participar aparecerão aqui.';}catch(error){more.textContent=friendly(error);}finally{more.disabled=false;}}more.onclick=load;await load();
}
export async function showAchievements(badges,player){
 for(const badge of badges||[]){
  await new Promise(resolve=>{
   const modal=document.createElement('dialog');modal.className='achievement-dialog';modal.setAttribute('aria-labelledby','achievementTitle');modal.innerHTML=`<small>NOVO EMBLEMA DESBLOQUEADO</small>${window.GTIUniverseUI.duoArtwork()}<div class="achievement-symbol">${esc(badge.icon)}</div><h2 id="achievementTitle">${esc(badge.name)}</h2><p>${esc(badge.description)}</p><button class="primary full" id="shareAchievement">Compartilhar conquista</button><form method="dialog"><button class="secondary full">Continuar</button></form>`;
   document.body.append(modal);modal.addEventListener('close',()=>{modal.remove();resolve();},{once:true});modal.querySelector('#shareAchievement').onclick=()=>shareDialog(badge,player);modal.showModal();
  });
 }
}
function shareDialog(badge,player){
 const modal=document.createElement('dialog');modal.className='achievement-dialog';modal.innerHTML='<h2>Compartilhar conquista</h2><p>Escolha o formato da imagem.</p><button class="primary full" data-size="1920">Story • 1080 × 1920</button><button class="secondary full" data-size="1350">Feed • 1080 × 1350</button><p role="status"></p><form method="dialog"><button class="secondary full">Fechar</button></form>';document.body.append(modal);modal.onclose=()=>modal.remove();modal.showModal();
 modal.querySelectorAll('[data-size]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{const season=await rpc('gti_missions_current_season');const {shareAchievement}=await import('/share-achievement.js?v=5.2.0');await shareAchievement(badge,player,season.name,Number(b.dataset.size));modal.querySelector('[role=status]').textContent='Imagem pronta. Se o compartilhamento não abriu, ela foi baixada.';}catch(e){if(e.name!=='AbortError')modal.querySelector('[role=status]').textContent='Não foi possível gerar a imagem. Tente novamente.';}finally{b.disabled=false;}});
}

async function renderPublicNotes(username){
 page('Notas públicas','<section id="publicNoteList"></section><button class="secondary full" id="morePublicNotes">Ver mais notas</button><p id="publicNoteMsg" role="status"></p>');
 let before=null,beforeId=null;const more=document.getElementById('morePublicNotes');
 async function load(){more.disabled=true;try{const rows=await rpc('gti_missions_public_notes',{p_username:username,p_before:before,p_before_id:beforeId});document.getElementById('publicNoteList').insertAdjacentHTML('beforeend',rows.map(n=>`<article class="rule-card"><h2>${esc(n.title||'Nota')}</h2><small>${date(n.created_at)}</small><p class="note-content">${esc(n.content)}</p></article>`).join(''));before=rows.at(-1)?.created_at||before;beforeId=rows.at(-1)?.id||beforeId;more.hidden=rows.length<10;if(!before)document.getElementById('publicNoteMsg').textContent='Nenhuma nota pública disponível.';}catch(error){notice(document.getElementById('publicNoteMsg'),error);}finally{more.disabled=false;}}
 more.onclick=load;await load();
}

// Receipts are built only after a successful submission, and stay in memory only.
export function showActivity(activity,player){
 document.querySelector('.activity-receipt')?.remove();
 const receipt=document.createElement('section');receipt.className='activity-receipt';receipt.setAttribute('aria-label','Atividade registrada');
 const data={...activity,date:new Date().toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'})};
 receipt.innerHTML=`<div><small>MISSÃO DO DIA REGISTRADA</small><b>${esc(data.title)} · +${fmt(data.xp||0)} XP</b><p>${esc(data.detail)}</p></div><button class="secondary" data-share-activity>Compartilhar imagem ↗</button><button class="receipt-close" aria-label="Dispensar comprovante">×</button>`;
 (app.querySelector('.app-content')||app.querySelector('main')||app).prepend(receipt);
 receipt.querySelector('.receipt-close').onclick=()=>receipt.remove();
 receipt.querySelector('[data-share-activity]').onclick=()=>{
  const modal=document.createElement('dialog');modal.className='achievement-dialog';modal.setAttribute('aria-label','Compartilhar atividade');
  modal.innerHTML=`<h2>Sua missão merece ser compartilhada.</h2><p>${esc(data.detail)}</p><p>O card inclui seu @, o registro e o XP. Compartilhe apenas o que quiser tornar público.</p><button class="primary full" data-size="1920">Story • 1080 × 1920</button><button class="secondary full" data-size="1350">Feed • 1080 × 1350</button><p role="status"></p><form method="dialog"><button class="secondary full">Fechar</button></form>`;
  document.body.append(modal);modal.onclose=()=>modal.remove();modal.showModal();
  modal.querySelectorAll('[data-size]').forEach(b=>b.onclick=async()=>{const controls=modal.querySelectorAll('[data-size]');controls.forEach(c=>c.disabled=true);try{const {shareActivity}=await import('/share-achievement.js?v=5.2.0');await shareActivity(data,player,Number(b.dataset.size));modal.querySelector('[role=status]').textContent='Imagem pronta para compartilhar ou baixar.';}catch(error){if(error.name!=='AbortError')modal.querySelector('[role=status]').textContent='Não foi possível gerar a imagem. Tente novamente.';}finally{controls.forEach(c=>c.disabled=false);}});
 };
}
