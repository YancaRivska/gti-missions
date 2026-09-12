(() => {
  'use strict';

  const ASSETS={
    hero:'/assets/mascot/chalote-hero-v1.webp',
    aqua:'/assets/challenges/aquaxp/chalote-aquaxp-v1.webp',
    rat:'/assets/challenges/rat-tech/chalote-rat-tech-v1.webp',
    reading:'/assets/challenges/reading/chalote-reading-v1.webp',
    offline:'/assets/challenges/screen-free/chalote-screen-free-v1.webp',
  };

  const pct=(value,total)=>Math.min(100,Math.round((Number(value||0)/Math.max(1,Number(total||0)))*100));
  const firstParty=statuses=>({
    reading:(statuses||[]).find(item=>item.slug==='reading'),
    offline:(statuses||[]).find(item=>item.slug==='screen-free'),
  });
  const community=statuses=>(statuses||[]).filter(item=>!['reading','screen-free'].includes(item.slug));
  const brandLogo=(small=false)=>`<div class="gti-brand ${small?'is-small':''}"><img src="/assets/ui/gti-missions-logo.svg" alt="GTI Missions" width="420" height="160"></div>`;
  const progressBar=(value,label)=>`<div class="neon-progress" role="progressbar" aria-label="${esc(label)}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(value)}"><i style="--value:${Math.max(0,Math.min(100,value))}%"></i></div>`;
  const screenHead=(icon,title,subtitle,back='challenges')=>`<header class="mission-screen-head"><button class="screen-back" data-nav="${back}" aria-label="Voltar">‹</button><div><h1><span>${icon}</span>${esc(title)}</h1><p>${esc(subtitle)}</p></div><button class="screen-alert" aria-label="Notificações">♢</button></header>`;

  async function universeStats(){
    try{return await rpc('gti_missions_my_progress')}
    catch{return await stats()}
  }

  function challengeTile({view,kind,image,eyebrow,title,description,meta,locked=false}){
    const tag=locked?'COMEÇAR':meta;
    return `<a class="universe-tile ${kind}" href="/?view=${view}" data-nav="${view}">
      <img src="${image}" alt="Chalote em ${esc(title)}" width="720" height="960">
      <div class="universe-tile-shade"></div>
      <div class="universe-tile-copy"><small>${eyebrow}</small><h2>${esc(title)}</h2><p>${esc(description)}</p><span>${esc(tag||'ABRIR →')}</span></div>
    </a>`;
  }

  async function renderHome(){
    const user=await authUser();
    app.innerHTML=`<main class="welcome-screen">
      <div class="welcome-atmosphere"></div>
      <section class="welcome-logo">${brandLogo()}<p>PEQUENAS AÇÕES.<br><b>GRANDES EVOLUÇÕES.</b></p></section>
      <section class="welcome-chalote"><div class="welcome-halo"></div><img src="${ASSETS.hero}" alt="Chalote, mascote oficial do GTI Missions" width="720" height="960"></section>
      <div class="welcome-copy"><p>Explore sua melhor versão.</p><button class="primary aurora-button" id="startMission">${user?'Continuar minha jornada →':'Começar agora →'}</button><small>Um futuro melhor começa com você.</small></div>
    </main>`;
    document.getElementById('startMission').onclick=()=>nav(user?'app':'login');
    installSupport();
  }

  async function renderDashboard(player){
    const [s,statuses,ranking,admin]=await Promise.all([
      universeStats(),customStatuses(),rpc('gti_missions_challenge_leaderboard',{p_challenge:'global',p_period:'month'}),isAdmin()
    ]);
    const worlds=firstParty(statuses),avatar=await avatarHtml(player.p.avatar_path,player.p.display_name,'small');
    const userRank=(ranking||[]).find(row=>row.user_id===player.u.id)?.rank||'—';
    const xpInLevel=Number(s.total_xp||0)%500,xpPct=pct(xpInLevel,500);
    const activeCount=2+Number(!!worlds.reading?.joined)+Number(!!worlds.offline?.joined);
    const weeklyParts=[pct(s.water_week_days,7),pct(s.exercise_week_days,s.exercise_week_target)];
    if(worlds.reading?.joined)weeklyParts.push(pct(worlds.reading.week_completed_days,worlds.reading.weekly_target_days));
    if(worlds.offline?.joined)weeklyParts.push(pct(worlds.offline.week_completed_days,worlds.offline.weekly_target_days));
    const overall=Math.round(weeklyParts.reduce((a,b)=>a+b,0)/Math.max(1,weeklyParts.length));
    app.innerHTML=shell(`<div class="reference-home">
      <header class="home-brandbar"><button class="icon-only" data-nav="challenges" aria-label="Abrir desafios">☰</button>${brandLogo(true)}<button class="icon-only" aria-label="Notificações">♢</button></header>
      <section class="home-greeting"><div><h1>Olá, ${esc(player.p.display_name.split(' ')[0])}!</h1><p>Disciplina hoje, um amanhã extraordinário.</p></div>${admin?'<button class="admin-chip" id="adminBtn">ADM</button>':''}</section>
      <section class="compact-player-card">
        <div class="player-avatar-wrap">${avatar}<span>${level(s.total_xp)}</span></div>
        <div><small>NÍVEL ${level(s.total_xp)} • ${levelName(s.total_xp)}</small><b>${fmt(s.total_xp)} / ${fmt((Math.floor(Number(s.total_xp||0)/500)+1)*500)} XP</b>${progressBar(xpPct,'Progresso do nível')}</div>
        <button data-nav="profile" aria-label="Abrir perfil">›</button>
      </section>
      <div class="compact-section-title"><h2>Meus desafios ativos</h2><button data-nav="challenges">Ver todos</button></div>
      <section class="active-world-grid">
        <button class="active-world aqua" data-nav="aqua"><span>💧</span><b>Água</b><small>${s.water_week_days} dia${Number(s.water_week_days)===1?'':'s'}</small></button>
        <button class="active-world rat" data-nav="tech"><span>⚡</span><b>RAT Tech</b><small>${s.exercise_week_days} treino${Number(s.exercise_week_days)===1?'':'s'}</small></button>
        <button class="active-world reading" data-nav="reading"><span>▣</span><b>Leitura</b><small>${worlds.reading?.joined?`${worlds.reading.week_completed_days} dias`:'Começar'}</small></button>
        <button class="active-world offline" data-nav="offline"><span>♧</span><b>Sem Tela</b><small>${worlds.offline?.joined?`${worlds.offline.week_completed_days} dias`:'Começar'}</small></button>
      </section>
      <button class="overall-card" data-nav="progress">
        <div class="overall-ring" style="--overall:${overall*3.6}deg"><span>${overall}%</span></div>
        <div><small>PROGRESSO GERAL</small><b>Suas missões desta semana</b><p>${activeCount} mundos ativos • ofensiva de ${s.activity_streak||0} dias</p></div><i>›</i>
      </button>
      <section class="home-stat-row"><div><span>🔥</span><b>${s.activity_streak||0}</b><small>dias seguidos</small></div><div><span>♛</span><b>#${userRank}</b><small>ranking</small></div><div><span>✦</span><b>${s.badges||0}</b><small>conquistas</small></div></section>
      <button class="primary aurora-button full journey-button" data-nav="challenges">Continuar minha jornada →</button>
      ${community(statuses).length?`<section class="community-mini"><small>MISSÕES DA COMUNIDADE</small>${community(statuses).slice(0,2).map(c=>`<button data-challenge="${c.id}"><span>${esc(c.icon)}</span><div><b>${esc(c.title)}</b><small>${c.joined?`${c.week_completed_days}/${c.weekly_target_days} nesta semana`:'Nova missão disponível'}</small></div><i>›</i></button>`).join('')}</section>`:''}
    </div>`,'app');
    bindNav();
    document.querySelectorAll('[data-challenge]').forEach(button=>button.onclick=()=>nav('challenge',false,{id:button.dataset.challenge}));
    if(admin)document.getElementById('adminBtn').onclick=()=>nav('admin');
  }

  async function renderChallenges(){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const worlds=firstParty(statuses);
    app.innerHTML=shell(`<div class="challenge-select-screen">
      <header class="home-brandbar"><button class="icon-only" data-nav="app" aria-label="Voltar">‹</button>${brandLogo(true)}<button class="icon-only" aria-label="Notificações">♢</button></header>
      <div class="select-intro"><h1>Escolha sua missão.</h1><p>Cada mundo transforma uma ação real em evolução.</p></div>
      <section class="challenge-select-grid">
        ${challengeTile({view:'aqua',kind:'aqua',image:ASSETS.aqua,eyebrow:'💧 HIDRATAÇÃO',title:'AquaXP League',description:'Mais saúde para ir mais longe.',meta:`${s.water_today_ml||0} ml hoje`})}
        ${challengeTile({view:'tech',kind:'rat',image:ASSETS.rat,eyebrow:'⚡ TREINO FÍSICO',title:'RAT Tech',description:'Força, movimento e consistência.',meta:`${s.exercise_week_days||0}/${s.exercise_week_target||3} treinos`})}
        ${challengeTile({view:'reading',kind:'reading',image:ASSETS.reading,eyebrow:'▣ CONHECIMENTO',title:'Desafio da Leitura',description:'Grandes mentes leem sempre.',meta:worlds.reading?.joined?`${worlds.reading.week_completed_days}/${worlds.reading.weekly_target_days} dias`:'COMEÇAR',locked:!worlds.reading?.joined})}
        ${challengeTile({view:'offline',kind:'offline',image:ASSETS.offline,eyebrow:'♧ VIDA REAL',title:'Desafio Sem Tela',description:'Mais presença. Mais vida.',meta:worlds.offline?.joined?`${worlds.offline.week_completed_days}/${worlds.offline.weekly_target_days} dias`:'COMEÇAR',locked:!worlds.offline?.joined})}
      </section>
      ${community(statuses).length?`<div class="compact-section-title"><h2>Missões da comunidade</h2></div><section class="mission-link-list">${community(statuses).map(c=>`<button data-challenge="${c.id}"><span>${esc(c.icon)}</span><div><b>${esc(c.title)}</b><small>${esc(c.description)}</small></div><i>›</i></button>`).join('')}</section>`:''}
    </div>`,'challenges');
    bindNav();
    document.querySelectorAll('[data-challenge]').forEach(button=>button.onclick=()=>nav('challenge',false,{id:button.dataset.challenge}));
  }

  async function renderTech(){
    const [s,u]=await Promise.all([universeStats(),authUser()]);
    const weekPct=pct(s.exercise_week_days,s.exercise_week_target);
    app.innerHTML=shell(`<div class="world-screen rat-world-screen">
      ${screenHead('⚡','Desafio RAT Tech','Treino. Movimento. Evolução.')}
      <section class="world-visual rat-visual"><div class="world-visual-glow"></div><img src="${ASSETS.rat}" alt="Chalote treinando com halter" width="720" height="960"><div class="hero-message"><b>Força é constância.</b><span>Seu corpo também merece evolução.</span></div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.activity_streak||0}</b><small>dias seguidos</small></div><div><span>⚡</span><b>${fmt(s.rat_xp||0)}</b><small>XP RAT Tech</small></div><div><span>🏋</span><b>${s.exercise_week_days||0}/${s.exercise_week_target||3}</b><small>treinos</small></div></section>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${s.exercise_week_days||0} de ${s.exercise_week_target||3} dias de treino</b></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal de treino')}</section>
      <section class="mission-link-list daily-missions"><small>MISSÕES DE TREINO</small><article><span>⚔</span><div><b>Complete o treino de hoje</b><small>5–19 min: +15 XP • 20+ min: +30 XP</small></div><i>${s.exercise_week_days? '✓':'+'}</i></article><article><span>🏅</span><div><b>Conquiste a semana</b><small>Treine ${s.exercise_week_target||3} dias e ganhe +100 XP</small></div><i>${s.exercise_week_days>=s.exercise_week_target?'✓':'›'}</i></article></section>
      <button class="primary aurora-button full world-primary-action" id="openRatRegister" type="button">Registrar meu treino →</button>
      <section class="world-form-card register-sheet" id="ratRegister" hidden><div class="form-card-title"><span>📸</span><div><small>PROVA DO TREINO</small><h2>Registrar treino</h2></div></div><p>A foto é tirada agora, fica privada e desaparece após 24 horas.</p><button class="secondary full camera-cta" id="openCamera" type="button">📷 Abrir câmera</button><div id="cameraMount"></div><div id="cameraMsg"></div><form id="ratForm"><label>Atividade<select id="ratActivity"><option>Academia</option><option>Corrida</option><option>Caminhada</option><option>Ciclismo</option><option>Alongamento</option><option>Funcional</option><option>Esporte</option><option>Outro treino</option></select></label><label>Duração (minutos)<input id="ratMinutes" type="number" min="1" max="300" value="30" inputmode="numeric" required></label><button class="primary aurora-button full">Registrar meu treino →</button></form><div id="ratMsg" aria-live="polite"></div></section>
    </div>`,'tech');
    bindNav();
    const ratRegister=document.getElementById('ratRegister');
    document.getElementById('openRatRegister').onclick=()=>{ratRegister.hidden=false;ratRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    const proof=bindProofCamera(),form=document.getElementById('ratForm');
    form.onsubmit=async event=>{event.preventDefault();const msg=document.getElementById('ratMsg'),button=event.submitter;let path=null;if(!proof.blob){msg.innerHTML='<div class="notice">Abra a câmera e tire uma foto do treino primeiro.</div>';return}try{button.disabled=true;path=await uploadCheckinPhoto(proof.blob,u.id,'tech');const result=await rpc('gti_missions_log_exercise',{p_exercise_name:document.getElementById('ratActivity').value,p_duration_minutes:+document.getElementById('ratMinutes').value,p_photo_path:path});msg.innerHTML=`<div class="success">Treino registrado${result?.xp_awarded?` • +${result.xp_awarded} XP`:''} ⚡</div>`;setTimeout(()=>renderTech(),500)}catch(error){if(path)await discardCheckinPhoto(path);button.disabled=false;msg.innerHTML=`<div class="notice">${esc(friendly(error))}</div>`}};
  }

  async function challengeHistory(id,userId){
    if(!id)return [];
    try{return await request(`/rest/v1/gti_missions_challenge_entries?challenge_id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(userId)}&select=entry_day,value,note,completed_at&order=entry_day.desc&limit=60`)||[]}
    catch{return []}
  }

  async function renderReading(player){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const challenge=firstParty(statuses).reading;
    if(!challenge)throw new Error('O portal da Leitura está indisponível.');
    const history=await challengeHistory(challenge.id,player.u.id),currentBook=history.find(row=>row.note)?.note||'Escolha sua próxima história';
    const dailyPct=pct(challenge.today_value,challenge.daily_target),weekPct=pct(challenge.week_completed_days,challenge.weekly_target_days);
    app.innerHTML=shell(`<div class="world-screen reading-world-screen">
      ${screenHead('▣','Desafio da Leitura','Mais histórias. Grandes possibilidades.')}
      <section class="world-visual reading-visual"><img src="${ASSETS.reading}" alt="Chalote lendo em uma biblioteca cyber" width="720" height="960"><div class="world-visual-caption"><small>MINHA LEITURA ATUAL</small><b>${esc(currentBook)}</b><span>${fmt(challenge.today_value)} / ${fmt(challenge.daily_target)} páginas hoje</span>${progressBar(dailyPct,'Meta diária de leitura')}</div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.reading_streak||0}</b><small>dias seguidos</small></div><div><span>▣</span><b>${fmt(s.reading_total_pages||0)}</b><small>páginas lidas</small></div><div><span>✦</span><b>${challenge.week_completed_days}/${challenge.weekly_target_days}</b><small>missões semana</small></div></section>
      <blockquote>“Ler é viajar sem sair do lugar.”</blockquote>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${challenge.week_completed_days} de ${challenge.weekly_target_days} dias de leitura</b></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal de leitura')}</section>
      <button class="primary aurora-button full world-primary-action" id="openReadingRegister" type="button">${challenge.joined?'Registrar leitura →':'Começar o desafio →'}</button>
      <section class="world-form-card register-sheet" id="readingRegister" hidden><div class="form-card-title"><span>▣</span><div><small>REGISTRO DE LEITURA</small><h2>${challenge.joined?'Registrar leitura':'Começar o desafio'}</h2></div></div><form id="readingForm"><label>Livro atual<input id="bookTitle" maxlength="180" value="${currentBook==='Escolha sua próxima história'?'':esc(currentBook)}" placeholder="Nome do livro" required></label><label>Páginas lidas agora<input id="readPages" type="number" min="1" max="200" value="20" inputmode="numeric" required></label><button class="primary aurora-button full">Registrar leitura →</button></form><div id="readingMsg" aria-live="polite"></div></section>
    </div>`,'reading');
    bindNav();
    const readingRegister=document.getElementById('readingRegister');
    document.getElementById('openReadingRegister').onclick=()=>{readingRegister.hidden=false;readingRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    document.getElementById('readingForm').onsubmit=async event=>{event.preventDefault();const msg=document.getElementById('readingMsg'),button=event.submitter;try{button.disabled=true;if(!challenge.joined)await rpc('gti_missions_join_challenge',{p_challenge_id:challenge.id});const result=await rpc('gti_missions_log_custom_challenge',{p_challenge_id:challenge.id,p_value:+document.getElementById('readPages').value,p_note:document.getElementById('bookTitle').value.trim(),p_photo_path:null});msg.innerHTML=`<div class="success">Leitura registrada${result?.xp_awarded?` • +${result.xp_awarded} XP`:''} 📖</div>`;setTimeout(()=>renderReading(player),500)}catch(error){button.disabled=false;msg.innerHTML=`<div class="notice">${esc(friendly(error))}</div>`}};
  }

  async function renderOffline(player){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const challenge=firstParty(statuses).offline;
    if(!challenge)throw new Error('O portal Sem Tela está indisponível.');
    const history=await challengeHistory(challenge.id,player.u.id),lastActivity=history.find(row=>row.note)?.note||'Um momento no mundo real';
    const dailyPct=pct(challenge.today_value,challenge.daily_target),weekPct=pct(challenge.week_completed_days,challenge.weekly_target_days);
    app.innerHTML=shell(`<div class="world-screen offline-world-screen">
      ${screenHead('♧','Desafio Sem Tela','Mais presença. Uma vida mais real.')}
      <section class="world-visual offline-visual"><img src="${ASSETS.offline}" alt="Chalote meditando sem telas" width="720" height="960"><div class="offline-quote">“Desconectar também é um passo para ir mais longe.”</div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.screen_free_streak||0}</b><small>dias seguidos</small></div><div><span>⌛</span><b>${fmt(s.screen_free_total_minutes||0)}</b><small>min sem telas</small></div><div><span>♧</span><b>${s.screen_free_total_days||0}</b><small>atividades reais</small></div></section>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${challenge.week_completed_days} de ${challenge.weekly_target_days} dias offline</b><p>${esc(lastActivity)}</p></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal sem tela')}</section>
      <button class="primary aurora-button full world-primary-action" id="openOfflineRegister" type="button">${challenge.joined?'Registrar meu dia offline →':'Começar o desafio →'}</button>
      <section class="world-form-card register-sheet" id="offlineRegister" hidden><div class="form-card-title"><span>♧</span><div><small>VIDA OFFLINE</small><h2>${challenge.joined?'Registrar meu momento':'Começar o desafio'}</h2></div></div><form id="offlineForm"><label>Atividade<select id="offlineActivity"><option>Caminhada ao ar livre</option><option>Meditação</option><option>Conversa com amigos</option><option>Esporte</option><option>Cozinhar</option><option>Hobby sem tela</option><option>Tempo em família</option><option>Outra atividade offline</option></select></label><label>Tempo sem telas (minutos)<input id="offlineMinutes" type="number" min="1" max="600" value="60" inputmode="numeric" required></label><button class="primary aurora-button full">Registrar meu dia offline →</button></form><div id="offlineMsg" aria-live="polite"></div></section>
      <p class="daily-progress-note">Hoje: ${fmt(challenge.today_value)} / ${fmt(challenge.daily_target)} min ${dailyPct>=100?'• missão concluída ✓':''}</p>
    </div>`,'offline');
    bindNav();
    const offlineRegister=document.getElementById('offlineRegister');
    document.getElementById('openOfflineRegister').onclick=()=>{offlineRegister.hidden=false;offlineRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    document.getElementById('offlineForm').onsubmit=async event=>{event.preventDefault();const msg=document.getElementById('offlineMsg'),button=event.submitter;try{button.disabled=true;if(!challenge.joined)await rpc('gti_missions_join_challenge',{p_challenge_id:challenge.id});const result=await rpc('gti_missions_log_custom_challenge',{p_challenge_id:challenge.id,p_value:+document.getElementById('offlineMinutes').value,p_note:document.getElementById('offlineActivity').value,p_photo_path:null});msg.innerHTML=`<div class="success">Momento offline registrado${result?.xp_awarded?` • +${result.xp_awarded} XP`:''} 🌿</div>`;setTimeout(()=>renderOffline(player),500)}catch(error){button.disabled=false;msg.innerHTML=`<div class="notice">${esc(friendly(error))}</div>`}};
  }

  function badgeCard(item){return `<article class="achievement-hex ${item.unlocked?'unlocked':'locked'} ${item.rare?'rare':''}"><div class="hex-icon"><span>${item.unlocked?item.icon:'▣'}</span></div><b>${esc(item.title)}</b><small>${esc(item.description)}</small>${item.unlocked?'<i>✓</i>':'<i>⌁</i>'}</article>`}

  async function renderAchievements(player,type='global'){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const worlds=firstParty(statuses),current=['global','aqua','rat-tech','reading','screen-free'].includes(type)?type:'global';
    const active=2+Number(!!worlds.reading?.joined)+Number(!!worlds.offline?.joined);
    const sets={
      global:[
        {icon:'✦',title:'Primeira Missão',description:'Complete sua primeira missão.',unlocked:Number(s.missions_completed)>0},
        {icon:'🔥',title:'Consistência 7',description:'Mantenha uma ofensiva de 7 dias.',unlocked:Number(s.activity_streak)>=7,rare:true},
        {icon:'◇',title:'Explorador de Mundos',description:'Participe de 3 desafios.',unlocked:active>=3},
        {icon:'♛',title:'Nível 5',description:'Alcance 2.000 XP no GTI Missions.',unlocked:Number(s.total_xp)>=2000,rare:true},
        {icon:'⚔',title:'100 Missões',description:'Complete cem missões reais.',unlocked:Number(s.missions_completed)>=100,rare:true},
        {icon:'🏆',title:'Colecionador',description:'Conquiste 10 selos semanais.',unlocked:Number(s.badges)>=10,rare:true},
      ],
      aqua:[
        {icon:'💧',title:'Primeiro Gole',description:'Registre água pela primeira vez.',unlocked:Number(s.water_total_ml)>0},
        {icon:'◉',title:'Meta Dominada',description:'Alcance a meta diária.',unlocked:Number(s.water_today_ml)>=Number(s.water_target_ml)},
        {icon:'🌊',title:'Maré de 3 Dias',description:'Complete três dias na semana.',unlocked:Number(s.water_week_days)>=3},
        {icon:'🔥',title:'Ofensiva Aqua',description:'Mantenha sete metas seguidas.',unlocked:Number(s.water_streak)>=7,rare:true},
        {icon:'🏅',title:'Guardião da Água',description:'Complete a missão semanal 7/7.',unlocked:Number(s.water_week_days)>=7,rare:true},
        {icon:'⚡',title:'10 Mil Litros',description:'Registre 10.000 ml no total.',unlocked:Number(s.water_total_ml)>=10000},
      ],
      'rat-tech':[
        {icon:'⚡',title:'Primeiro Treino',description:'Registre sua primeira atividade.',unlocked:Number(s.exercise_total_sessions)>0},
        {icon:'🏋',title:'Força em Movimento',description:'Complete 60 minutos de treino.',unlocked:Number(s.exercise_total_minutes)>=60},
        {icon:'🔥',title:'Três Dias Ativos',description:'Treine em três dias da semana.',unlocked:Number(s.exercise_week_days)>=3},
        {icon:'🏅',title:'Semana RAT Tech',description:'Complete sua meta semanal.',unlocked:Number(s.exercise_week_days)>=Number(s.exercise_week_target),rare:true},
        {icon:'⚔',title:'10 Treinos',description:'Registre dez sessões.',unlocked:Number(s.exercise_total_sessions)>=10},
        {icon:'♛',title:'Atleta Cyber',description:'Acumule 1.000 minutos.',unlocked:Number(s.exercise_total_minutes)>=1000,rare:true},
      ],
      reading:[
        {icon:'▣',title:'Leitor Iniciante',description:'Registre suas primeiras páginas.',unlocked:Number(s.reading_total_pages)>0},
        {icon:'✦',title:'Meta de Hoje',description:'Leia 20 páginas em um dia.',unlocked:Number(s.reading_today_pages)>=Number(s.reading_daily_target||20)},
        {icon:'◇',title:'Viajante de Histórias',description:'Leia em três dias da semana.',unlocked:Number(s.reading_week_days)>=3},
        {icon:'🏅',title:'Semana da Leitura',description:'Complete a meta semanal.',unlocked:Number(s.reading_week_days)>=Number(s.reading_week_target||5),rare:true},
        {icon:'▤',title:'100 Páginas',description:'Leia cem páginas no total.',unlocked:Number(s.reading_total_pages)>=100},
        {icon:'♛',title:'Mente Aberta',description:'Leia mil páginas no total.',unlocked:Number(s.reading_total_pages)>=1000,rare:true},
      ],
      'screen-free':[
        {icon:'♧',title:'Primeira Pausa',description:'Registre seu primeiro tempo offline.',unlocked:Number(s.screen_free_total_minutes)>0},
        {icon:'⌛',title:'Uma Hora Presente',description:'Complete 60 minutos sem telas.',unlocked:Number(s.screen_free_today_minutes)>=Number(s.screen_free_daily_target||60)},
        {icon:'◇',title:'Vida Real',description:'Faça três atividades offline.',unlocked:Number(s.screen_free_total_days)>=3},
        {icon:'🏅',title:'Semana Presente',description:'Complete a meta semanal.',unlocked:Number(s.screen_free_week_days)>=Number(s.screen_free_week_target||4),rare:true},
        {icon:'🌿',title:'Cinco Horas Livres',description:'Some 300 minutos offline.',unlocked:Number(s.screen_free_total_minutes)>=300},
        {icon:'♛',title:'Equilíbrio Digital',description:'Some 1.000 minutos offline.',unlocked:Number(s.screen_free_total_minutes)>=1000,rare:true},
      ]
    };
    const items=sets[current],unlocked=items.filter(item=>item.unlocked).length;
    app.innerHTML=shell(`<div class="achievement-screen">
      ${screenHead('✦','Conquistas por Desafio','Cada hábito abre uma nova relíquia.','app')}
      <nav class="world-tabs achievement-tabs">${[['global','Total'],['aqua','Água'],['rat-tech','RAT Tech'],['reading','Leitura'],['screen-free','Sem Tela']].map(([id,label])=>`<button class="${current===id?'active':''}" data-achievement="${id}">${label}</button>`).join('')}</nav>
      <section class="achievement-summary"><img src="${current==='aqua'?ASSETS.aqua:current==='rat-tech'?ASSETS.rat:current==='reading'?ASSETS.reading:current==='screen-free'?ASSETS.offline:ASSETS.hero}" alt="Chalote celebrando conquistas" width="720" height="960"><div><small>${current==='global'?'GTI MISSIONS':current.toUpperCase()}</small><b>${unlocked}/${items.length} conquistas</b>${progressBar(pct(unlocked,items.length),'Conquistas desbloqueadas')}</div></section>
      <section class="achievement-grid-v3">${items.map(badgeCard).join('')}</section>
      <blockquote>“Cada passo conta. Você está evoluindo.”</blockquote>
    </div>`,'achievements');
    bindNav();
    document.querySelectorAll('[data-achievement]').forEach(button=>button.onclick=()=>nav('achievements',false,{type:button.dataset.achievement}));
  }

  async function renderProgress(){
    const s=await universeStats(),total=Number(s.total_xp||0),xpInLevel=total%500,next=500-xpInLevel;
    const contributions=[
      {kind:'aqua',icon:'💧',name:'AquaXP League',xp:Number(s.aqua_xp||0),joined:true,meta:`${s.water_week_days||0}/7 dias nesta semana`},
      {kind:'rat',icon:'⚡',name:'RAT Tech',xp:Number(s.rat_xp||0),joined:true,meta:`${s.exercise_week_days||0}/${s.exercise_week_target||3} treinos`},
      {kind:'reading',icon:'▣',name:'Leitura',xp:Number(s.reading_xp||0),joined:!!s.reading_joined,meta:`${s.reading_week_days||0}/${s.reading_week_target||5} dias de leitura`},
      {kind:'offline',icon:'♧',name:'Sem Tela',xp:Number(s.screen_free_xp||0),joined:!!s.screen_free_joined,meta:`${s.screen_free_week_days||0}/${s.screen_free_week_target||4} dias offline`},
    ];
    app.innerHTML=shell(`<div class="total-screen">
      ${screenHead('♜','Progresso Total','Juntos por um amanhã mais saudável.','app')}
      <section class="level-shield"><span>NÍVEL ${level(total)}</span><b>${fmt(total)} XP</b><small>${fmt(next)} XP para o nível ${level(total)+1}</small>${progressBar(pct(xpInLevel,500),'Progresso total do nível')}</section>
      <section class="total-stat-row"><div><span>🔥</span><b>${s.activity_streak||0}</b><small>dias seguidos</small></div><div><span>⚔</span><b>${s.missions_completed||0}</b><small>missões</small></div><div><span>🏆</span><b>${s.badges||0}</b><small>conquistas</small></div></section>
      <section class="contribution-panel"><div class="compact-section-title"><h2>Contribuição por desafio</h2></div>${contributions.map(item=>item.joined?`<article><span class="contribution-symbol ${item.kind}">${item.icon}</span><div><b>${item.name}</b><small>${item.meta}</small>${progressBar(total?pct(item.xp,total):0,`Contribuição de ${item.name}`)}</div><em>${total?pct(item.xp,total):0}%</em></article>`:`<article class="not-joined"><span class="contribution-symbol ${item.kind}">${item.icon}</span><div><b>${item.name}</b><small>Você ainda não participa deste desafio.</small></div></article>`).join('')}</section>
      <blockquote>“Cada passo conta. Você está fazendo a diferença.”</blockquote>
    </div>`,'app');
    bindNav();
  }

  function rankingScore(row,type){
    if(type==='global')return `${fmt(row.xp)} XP`;
    if(type==='aqua')return `${fmt(Number(row.score)/1000)} L`;
    if(type==='reading')return `${fmt(row.score)} pág.`;
    if(type==='screen-free')return `${fmt(row.score)} min`;
    return `${fmt(row.score)} min`;
  }

  async function renderLeague(player,type='global',period='month'){
    const validTypes=['global','aqua','rat-tech','reading','screen-free'],validPeriods=['week','month','all'];
    const current=validTypes.includes(type)?type:'global',range=validPeriods.includes(period)?period:'month';
    const rows=await rpc('gti_missions_challenge_leaderboard',{p_challenge:current,p_period:range});
    const cards=[];
    for(const row of rows||[]){
      const avatar=await avatarHtml(row.avatar_path,row.display_name,'small'),medal=Number(row.rank)===1?'♛':Number(row.rank)===2?'♜':Number(row.rank)===3?'♝':row.rank;
      cards.push(`<article class="ranking-row ${row.user_id===player.u.id?'me':''}"><strong>${medal}</strong><div class="ranking-user">${avatar}<div><b>${esc(row.display_name)}</b><small>@${esc(row.username)}${current==='global'?` • ${row.participating_challenges} mundo${Number(row.participating_challenges)===1?'':'s'}`:''}</small></div></div><span>${rankingScore(row,current)}${current!=='global'&&row.xp?`<small>${fmt(row.xp)} XP</small>`:''}</span></article>`);
    }
    const titles={global:['🏆','Ranking Geral','Todos os exploradores. Um futuro maior.'],aqua:['💧','Ranking da Água','Juntos por um amanhã mais saudável.'],'rat-tech':['⚡','Ranking RAT Tech','Mais movimento. Mais energia.'],reading:['▣','Ranking da Leitura','Mais livros. Mais horizontes.'],'screen-free':['♧','Ranking Sem Tela','Mais vida real. Mais bem-estar.']};
    const [icon,title,subtitle]=titles[current];
    app.innerHTML=shell(`<div class="ranking-screen">
      ${screenHead(icon,title,subtitle,'app')}
      <nav class="world-tabs ranking-world-tabs">${[['global','Geral'],['aqua','Água'],['rat-tech','RAT Tech'],['reading','Leitura'],['screen-free','Sem Tela']].map(([id,label])=>`<button class="${current===id?'active':''}" data-ranking-type="${id}">${label}</button>`).join('')}</nav>
      <nav class="period-tabs">${[['week','Esta semana'],['month','Este mês'],['all','Geral']].map(([id,label])=>`<button class="${range===id?'active':''}" data-ranking-period="${id}">${label}</button>`).join('')}</nav>
      ${current==='global'?'<section class="ranking-explainer"><span>✦</span><p>O ranking geral soma o XP dos desafios em que cada pessoa participa. Ninguém perde posição por não entrar em um mundo.</p></section>':''}
      <div class="ranking-columns"><span>#</span><span>EXPLORADOR</span><span>${current==='global'?'XP':'PROGRESSO'}</span></div>
      <section class="ranking-list">${cards.length?cards.join(''):'<div class="empty">Ainda não há progresso neste ranking.</div>'}</section>
      <blockquote>${current==='aqua'?'“Cada gole conta.”':current==='rat-tech'?'“Movimento hoje. Energia amanhã.”':current==='reading'?'“Grandes leitores constroem grandes futuros.”':current==='screen-free'?'“Menos tela. Mais do que realmente importa.”':'“A evolução fica maior quando é coletiva.”'}</blockquote>
    </div>`,'league');
    bindNav();
    document.querySelectorAll('[data-ranking-type]').forEach(button=>button.onclick=()=>nav('league',false,{type:button.dataset.rankingType,period:range}));
    document.querySelectorAll('[data-ranking-period]').forEach(button=>button.onclick=()=>nav('league',false,{type:current,period:button.dataset.rankingPeriod}));
  }

  window.GTIUniverseUI={renderHome,renderDashboard,renderChallenges,renderTech,renderReading,renderOffline,renderAchievements,renderProgress,renderLeague,brandLogo};
  render();
})();
