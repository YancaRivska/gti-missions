(() => {
  'use strict';

  const ASSETS={
    hero:'/assets/mascot/chalote-hero-v1.webp',
    aqua:'/assets/challenges/aquaxp/chalote-aquaxp-v1.webp',
    rat:'/assets/mascot/scarlote-cyber-v1.webp',
    reading:'/assets/challenges/reading/chalote-reading-v1.webp',
    offline:'/assets/mascot/scarlote-cyber-v1.webp',
    scarlote:'/assets/mascot/scarlote-cyber-v1.webp',
  };

  const shirtUrl='https://wa.me/5519991918817?text='+encodeURIComponent('Olá! Vim pelo GTI Missions e quero mais informações sobre a camiseta Galera do TI — Drop 002. 💙');
  const duoArtwork=()=>`<div class="duo-art" aria-hidden="true"><img src="${ASSETS.hero}" alt="" width="720" height="960" decoding="async"><img src="${ASSETS.scarlote}" alt="" width="720" height="901" decoding="async"></div>`;
  const playerProgress=total=>`<a class="player-progress" href="/?view=progress" data-nav="progress"><div><b>NÍVEL ${level(total)}</b><span>${fmt(Number(total||0)%500)} / 500 XP</span></div>${progressBar(pct(Number(total||0)%500,500),'Progresso do nível')}<small>${esc(levelName(total))} · Ver progresso →</small></a>`;
  const promoBanner=()=>`<a class="promo-banner" href="/?view=merch" data-nav="merch"><div><small>GALERA DO TI</small><h2>DROP 002</h2><p>Mais que código.<br>Uma comunidade real.</p><span>Ver camiseta →</span></div><div class="shirt-art"><img src="/assets/reference/drop-002.webp" alt="Camiseta preta da Galera do TI, frente e costas" loading="lazy" decoding="async" width="1229" height="1536"></div></a>`;
  function renderMerch(){app.innerHTML=shell(`<div class="merch-screen">${screenHead('','Camiseta Galera do TI','Mais que código. Uma comunidade real.','app')}<small class="world-label">DROP 002</small><div class="shirt-art merch-art"><img src="/assets/reference/drop-002.webp" alt="Arte da camiseta Galera do TI Drop 002, frente e costas" width="1229" height="1536"></div><h2>Vista a sua comunidade.</h2><p>Gostou da camiseta? Fale com a Yanca para saber os tamanhos, valores e como pedir a sua.</p><a class="primary full whatsapp-cta" href="${shirtUrl}" target="_blank" rel="noopener noreferrer">Quero mais informações da camiseta ↗</a></div>`,'app');bindNav();}

  const pct=(value,total)=>Math.min(100,Math.round((Number(value||0)/Math.max(1,Number(total||0)))*100));
  const firstParty=statuses=>({
    reading:(statuses||[]).find(item=>item.slug==='reading'),
    offline:(statuses||[]).find(item=>item.slug==='screen-free'),
  });
  const community=statuses=>(statuses||[]).filter(item=>!['reading','screen-free'].includes(item.slug));
  const brandLogo=(small=false)=>`<div class="gti-brand ${small?'is-small':''}"><img src="/assets/ui/gti-missions-logo.svg" alt="GTI Missions" width="420" height="160"></div>`;
  const progressBar=(value,label)=>`<div class="neon-progress" role="progressbar" aria-label="${esc(label)}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(value)}"><i style="--value:${Math.max(0,Math.min(100,value))}%"></i></div>`;
  const screenHead=(icon,title,subtitle,back='challenges')=>`<header class="mission-screen-head"><button class="screen-back" data-nav="${back}" aria-label="Voltar">‹</button><div><h1><span>${icon}</span>${esc(title)}</h1><p>${esc(subtitle)}</p></div><span class="world-label" aria-hidden="true">GTI</span></header>`;

  async function universeStats(){
    try{return await rpc('gti_missions_my_progress')}
    catch{return await stats()}
  }

  function challengeTile({view,kind,image,eyebrow,title,description,meta,locked=false}){
    const tag=locked?'COMEÇAR':meta;
    return `<a class="universe-tile ${kind}" href="/?view=${view}" data-nav="${view}">
      <img src="${image}" alt="Mascote GTI em ${esc(title)}" width="720" height="960" loading="lazy" decoding="async">
      <div class="universe-tile-shade"></div>
      <div class="universe-tile-copy"><small>${eyebrow}</small><h2>${esc(title)}</h2><p>${esc(description)}</p><span>${esc(tag||'ABRIR →')}</span></div>
    </a>`;
  }

  async function renderHome(){
    const user=await authUser();
    app.innerHTML=`<main class="welcome-screen welcome-clean welcome-community">
      <section class="welcome-panel">
        <div class="welcome-logo">${brandLogo()}</div>
        <div class="welcome-copy"><small>MISSÕES DIÁRIAS • PROGRESSO REAL</small><h1>Um passo por dia.</h1><p>Água, treino e hábitos em um só lugar.</p><button class="primary" id="startMission">${user?'Continuar':'Começar agora'}</button></div>
        ${duoArtwork()}
      </section>
      ${promoBanner()}
      <nav class="welcome-links"><a href="/?view=terms" data-nav="terms">Termos</a><a href="/?view=privacy" data-nav="privacy">Privacidade</a></nav>
    </main>`;
    document.getElementById('startMission').onclick=()=>nav(user?'app':'login');
    bindNav();
    installSupport();
    return true;
  }

  async function renderDashboard(player){
    const [s,statuses,season,admin]=await Promise.all([
      stats(),customStatuses(),rpc('gti_missions_current_season'),isAdmin()
    ]);
    const worlds=firstParty(statuses),avatar=await avatarHtml(player.p.avatar_path,player.p.display_name,'small');
    const waterPct=pct(s.water_today_ml,s.water_target_ml);
    app.innerHTML=shell(`<div class="reference-home">
      <header class="home-brandbar"><button class="icon-only" data-nav="challenges" aria-label="Abrir desafios">☰</button>${brandLogo(true)}<button class="avatar-button" data-nav="profile" aria-label="Abrir perfil">${avatar}</button></header>
      <section class="home-greeting"><div><h1>Olá, ${esc(player.p.display_name.split(' ')[0])}</h1><p>@${esc(player.p.username)}</p></div>${admin?'<button class="admin-chip" id="adminBtn">ADM</button>':''}</section>
      <section class="player-hero">${duoArtwork()}<div class="player-hero-brand">${brandLogo()}<p>Cada ação real constrói um futuro maior.</p></div></section>
      ${playerProgress(s.total_xp)}
      <section class="home-stat-row player-metrics"><div><b>🔥 ${s.activity_streak||0}</b><small>dias seguidos</small></div><div><b>${fmt(s.total_xp)} XP</b><small>XP total</small></div><div><b>${s.badges||0}</b><small>selos</small></div>${s.monthly_rank?`<div><b>#${s.monthly_rank}</b><small>ranking do mês</small></div>`:''}</section>
      <a class="season-banner" href="/?view=seasons" data-nav="seasons"><div><small>TEMPORADA ATUAL</small><h2>${esc(season.name)}</h2><p>${fmt(s.monthly_xp)} XP neste capítulo</p></div><span>↗</span></a>
      <section class="today-card">
        <div class="today-heading"><div><small>MISSÕES DE HOJE</small><h2>Seu próximo passo</h2></div><button data-nav="seasons">${season.requires_code&&!season.joined?'Inserir código':'Temporada'}</button></div>
        <button class="today-mission" data-nav="aqua"><span>💧</span><div><b>Água</b><small>${fmt(s.water_today_ml)} / ${fmt(s.water_target_ml)} ml</small>${progressBar(waterPct,'Meta diária de água')}</div><i>${waterPct>=100?'✓':'+'}</i></button>
        <button class="today-mission" data-nav="tech"><span>🏋️</span><div><b>Treino</b><small>${s.exercise_today_completed?'Concluído hoje':`${s.exercise_week_days||0}/${s.exercise_week_target||3} nesta semana`}</small></div><i>${s.exercise_today_completed?'✓':'+'}</i></button>
      </section>
      <button class="next-badge-card" data-nav="collection"><span>✦</span><div><small>PRÓXIMO EMBLEMA</small><b>${s.next_badge?esc(s.next_badge):'Ver minha coleção'}</b></div><i>›</i></button>
      <div class="compact-section-title"><h2>Outras missões</h2><button data-nav="challenges">Ver todas</button></div>
      <section class="active-world-grid">
        <button class="active-world aqua" data-nav="aqua"><span>💧</span><b>Água</b><small>${s.water_week_days} dia${Number(s.water_week_days)===1?'':'s'}</small></button>
        <button class="active-world rat" data-nav="tech"><span>⚡</span><b>RAT Tech</b><small>${s.exercise_week_days} treino${Number(s.exercise_week_days)===1?'':'s'}</small></button>
        <button class="active-world reading" data-nav="reading"><span>▣</span><b>Leitura</b><small>${worlds.reading?.joined?`${worlds.reading.week_completed_days} dias`:'Começar'}</small></button>
        <button class="active-world offline" data-nav="offline"><span>♧</span><b>Sem Tela</b><small>${worlds.offline?.joined?`${worlds.offline.week_completed_days} dias`:'Começar'}</small></button>
      </section>
      ${promoBanner()}
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
      <header class="home-brandbar"><button class="icon-only" data-nav="app" aria-label="Voltar">‹</button>${brandLogo(true)}<span class="world-label" aria-hidden="true">GTI</span></header>
      <div class="select-intro"><h1>Escolha sua missão.</h1><p>Cada mundo transforma uma ação real em evolução.</p></div>
      <section class="challenge-select-grid">
        ${challengeTile({view:'aqua',kind:'aqua',image:ASSETS.aqua,eyebrow:'💧 MUNDO ÁGUA',title:'AquaXP League',description:'Mais saúde para ir mais longe.',meta:`${s.water_today_ml||0} ml hoje`})}
        ${challengeTile({view:'tech',kind:'rat',image:ASSETS.rat,eyebrow:'⚡ MUNDO ENERGIA',title:'RAT Tech',description:'Força, movimento e consistência.',meta:`${s.exercise_week_days||0}/${s.exercise_week_target||3} treinos`})}
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
      ${screenHead('🏋️','Desafio RAT Tech','Treino. Movimento. Evolução.')}
      <section class="world-visual rat-visual"><div class="world-visual-glow"></div><img src="${ASSETS.rat}" alt="Mascote escuro do mundo de treino" width="720" height="960"><div class="hero-message"><b>Força é constância.</b><span>Seu corpo também merece evolução.</span></div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.activity_streak||0}</b><small>dias seguidos</small></div><div><span>⚡</span><b>${fmt(s.rat_xp||0)}</b><small>XP RAT Tech</small></div><div><span>🏋</span><b>${s.exercise_week_days||0}/${s.exercise_week_target||3}</b><small>treinos</small></div></section>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${s.exercise_week_days||0} de ${s.exercise_week_target||3} dias de treino</b></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal de treino')}</section>
      <section class="mission-link-list daily-missions"><small>MISSÕES DE TREINO</small><article><span>⚔</span><div><b>Complete o treino de hoje</b><small>5–19 min: +15 XP • 20+ min: +30 XP</small></div><i>${s.exercise_week_days? '✓':'+'}</i></article><article><span>🏅</span><div><b>Conquiste a semana</b><small>Treine ${s.exercise_week_target||3} dias e ganhe +100 XP</small></div><i>${s.exercise_week_days>=s.exercise_week_target?'✓':'›'}</i></article></section>
      <button class="primary aurora-button full world-primary-action" id="openRatRegister" type="button">Registrar meu treino →</button>
      <section class="world-form-card register-sheet" id="ratRegister" hidden><div class="form-card-title"><span>🏋️</span><div><small>TREINO DE HOJE</small><h2>Registrar treino</h2></div></div><form id="ratForm"><label>Atividade<select id="ratActivity"><option>Academia</option><option>Corrida</option><option>Caminhada</option><option>Ciclismo</option><option>Alongamento</option><option>Funcional</option><option>Esporte</option><option>Outro treino</option></select></label><label>Duração (minutos)<input id="ratMinutes" type="number" min="5" max="300" value="30" inputmode="numeric" required></label><button class="primary aurora-button full">Concluir treino de hoje</button></form><div id="ratMsg" aria-live="polite"></div></section>
    </div>`,'tech');
    bindNav();
    const ratRegister=document.getElementById('ratRegister');
    document.getElementById('openRatRegister').onclick=()=>{ratRegister.hidden=false;ratRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    const form=document.getElementById('ratForm');
    form.onsubmit=async event=>{
      event.preventDefault();
      if(!confirm('Concluir o treino de hoje? Essa confirmação registra sua atividade.'))return;
      const msg=document.getElementById('ratMsg'),button=event.submitter||form.querySelector('button');
      try{button.disabled=true;const detail=`Hoje treinei: ${document.getElementById('ratActivity').value} · ${document.getElementById('ratMinutes').value} minutos.`;const result=await rpc('gti_missions_submit_exercise',{p_exercise_name:document.getElementById('ratActivity').value,p_duration_minutes:+document.getElementById('ratMinutes').value});msg.textContent=result.already_completed?'Seu treino de hoje já está concluído.':`Treino concluído! +${result.xp_awarded||0} XP`;
      await (await import('/product.js?v=5.2.0')).showAchievements(result.unlocked_badges,await profile());await renderTech();if(!result.already_completed)(await import('/product.js?v=5.2.0')).showActivity({title:"RAT Tech",detail,icon:"⚡",xp:result.xp_awarded},await profile());
      }catch(error){button.disabled=false;msg.textContent=friendly(error);}
    };

  }

  async function challengeHistory(id,userId){
    if(!id)return [];
    try{return await request(`/rest/v1/gti_missions_challenge_entries?challenge_id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(userId)}&select=entry_day,value,note,completed_at&order=entry_day.desc&limit=10`)||[]}
    catch{return []}
  }

  async function renderReading(player){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const challenge=firstParty(statuses).reading;
    if(!challenge)throw new Error('O portal da Leitura está indisponível.');
    const history=await challengeHistory(challenge.id,player.u.id),currentBook=history.find(row=>row.note)?.note||'Escolha sua próxima história';
    const dailyPct=pct(challenge.today_value,challenge.daily_target),weekPct=pct(challenge.week_completed_days,challenge.weekly_target_days);
    app.innerHTML=shell(`<div class="world-screen reading-world-screen">
      ${screenHead('📖','Desafio da Leitura','Mais histórias. Grandes possibilidades.')}
      <section class="world-visual reading-visual"><img src="${ASSETS.reading}" alt="Chalote lendo em uma biblioteca cyber" width="720" height="960"><div class="world-visual-caption"><small>MINHA LEITURA ATUAL</small><b>${esc(currentBook)}</b><span>${fmt(challenge.today_value)} / ${fmt(challenge.daily_target)} páginas hoje</span>${progressBar(dailyPct,'Meta diária de leitura')}</div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.reading_streak||0}</b><small>dias seguidos</small></div><div><span>▣</span><b>${fmt(s.reading_total_pages||0)}</b><small>páginas lidas</small></div><div><span>✦</span><b>${challenge.week_completed_days}/${challenge.weekly_target_days}</b><small>missões semana</small></div></section>
      <a class="journal-prompt" href="/?view=notes" data-nav="notes"><small>O QUE EU APRENDI</small><b>Guarde uma ideia da sua leitura.</b><span>Abrir meu diário →</span></a>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${challenge.week_completed_days} de ${challenge.weekly_target_days} dias de leitura</b></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal de leitura')}</section>
      <button class="primary aurora-button full world-primary-action" id="openReadingRegister" type="button">${challenge.joined?'Registrar leitura →':'Começar o desafio →'}</button>
      <section class="world-form-card register-sheet" id="readingRegister" hidden><div class="form-card-title"><span>▣</span><div><small>REGISTRO DE LEITURA</small><h2>${challenge.joined?'Registrar leitura':'Começar o desafio'}</h2></div></div><form id="readingForm"><label>Livro atual<input id="bookTitle" maxlength="180" value="${currentBook==='Escolha sua próxima história'?'':esc(currentBook)}" placeholder="Nome do livro" required></label><label>Páginas lidas agora<input id="readPages" type="number" min="1" max="200" value="20" inputmode="numeric" required></label><button class="primary aurora-button full">Registrar leitura →</button></form><div id="readingMsg" aria-live="polite"></div></section>
    </div>`,'reading');
    bindNav();
    const readingRegister=document.getElementById('readingRegister');
    document.getElementById('openReadingRegister').onclick=()=>{readingRegister.hidden=false;readingRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    document.getElementById('readingForm').onsubmit=async event=>{event.preventDefault();const msg=document.getElementById('readingMsg'),button=event.submitter;try{button.disabled=true;if(!challenge.joined)await rpc('gti_missions_join_challenge',{p_challenge_id:challenge.id});const result=await rpc('gti_missions_submit_custom',{p_challenge_id:challenge.id,p_value:+document.getElementById('readPages').value,p_note:document.getElementById('bookTitle').value.trim(),p_request_id:crypto.randomUUID()});msg.innerHTML=`<div class="success">Leitura registrada${result?.xp_awarded?` • +${result.xp_awarded} XP`:''} 📖</div>`;const detail=`Hoje li ${document.getElementById('readPages').value} páginas · ${document.getElementById('bookTitle').value.trim()}`;await renderReading(player);(await import('/product.js?v=5.2.0')).showActivity({title:'Desafio da Leitura',detail,icon:'📖',xp:result.xp_awarded},player.p)}catch(error){button.disabled=false;msg.innerHTML=`<div class="notice">${esc(friendly(error))}</div>`}};
  }

  async function renderOffline(player){
    const [s,statuses]=await Promise.all([universeStats(),customStatuses()]);
    const challenge=firstParty(statuses).offline;
    if(!challenge)throw new Error('O portal Sem Tela está indisponível.');
    const history=await challengeHistory(challenge.id,player.u.id),lastActivity=history.find(row=>row.note)?.note||'Um momento no mundo real';
    const dailyPct=pct(challenge.today_value,challenge.daily_target),weekPct=pct(challenge.week_completed_days,challenge.weekly_target_days);
    app.innerHTML=shell(`<div class="world-screen offline-world-screen">
      ${screenHead('🌿','Desafio Sem Tela','Mais presença. Uma vida mais real.')}
      <section class="world-visual offline-visual"><img src="${ASSETS.offline}" alt="Mascote escuro do mundo Sem Tela" width="720" height="960"><div class="offline-quote">“Desconectar também é um passo para ir mais longe.”</div></section>
      <section class="world-stat-grid"><div><span>🔥</span><b>${s.screen_free_streak||0}</b><small>dias seguidos</small></div><div><span>⌛</span><b>${fmt(s.screen_free_total_minutes||0)}</b><small>min sem telas</small></div><div><span>♧</span><b>${s.screen_free_total_days||0}</b><small>atividades reais</small></div></section>
      <section class="world-progress-card"><div><small>META DA SEMANA</small><b>${challenge.week_completed_days} de ${challenge.weekly_target_days} dias offline</b><p>${esc(lastActivity)}</p></div><span>${weekPct}%</span>${progressBar(weekPct,'Meta semanal sem tela')}</section>
      <button class="primary aurora-button full world-primary-action" id="openOfflineRegister" type="button">${challenge.joined?'Registrar meu dia offline →':'Começar o desafio →'}</button>
      <section class="world-form-card register-sheet" id="offlineRegister" hidden><div class="form-card-title"><span>♧</span><div><small>VIDA OFFLINE</small><h2>${challenge.joined?'Registrar meu momento':'Começar o desafio'}</h2></div></div><form id="offlineForm"><label>Atividade<select id="offlineActivity"><option>Caminhada ao ar livre</option><option>Meditação</option><option>Conversa com amigos</option><option>Esporte</option><option>Cozinhar</option><option>Hobby sem tela</option><option>Tempo em família</option><option>Outra atividade offline</option></select></label><label>Tempo sem telas (minutos)<input id="offlineMinutes" type="number" min="1" max="600" value="60" inputmode="numeric" required></label><button class="primary aurora-button full">Registrar meu dia offline →</button></form><div id="offlineMsg" aria-live="polite"></div></section>
      <p class="daily-progress-note">Hoje: ${fmt(challenge.today_value)} / ${fmt(challenge.daily_target)} min ${dailyPct>=100?'• missão concluída ✓':''}</p>
    </div>`,'offline');
    bindNav();
    const offlineRegister=document.getElementById('offlineRegister');
    document.getElementById('openOfflineRegister').onclick=()=>{offlineRegister.hidden=false;offlineRegister.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'})};
    document.getElementById('offlineForm').onsubmit=async event=>{event.preventDefault();const msg=document.getElementById('offlineMsg'),button=event.submitter;try{button.disabled=true;if(!challenge.joined)await rpc('gti_missions_join_challenge',{p_challenge_id:challenge.id});const result=await rpc('gti_missions_submit_custom',{p_challenge_id:challenge.id,p_value:+document.getElementById('offlineMinutes').value,p_note:document.getElementById('offlineActivity').value,p_request_id:crypto.randomUUID()});msg.innerHTML=`<div class="success">Momento offline registrado${result?.xp_awarded?` • +${result.xp_awarded} XP`:''} 🌿</div>`;const detail=`Hoje passei ${document.getElementById('offlineMinutes').value} minutos sem tela · ${document.getElementById('offlineActivity').value}`;await renderOffline(player);(await import('/product.js?v=5.2.0')).showActivity({title:'Desafio Sem Tela',detail,icon:'🌿',xp:result.xp_awarded},player.p)}catch(error){button.disabled=false;msg.innerHTML=`<div class="notice">${esc(friendly(error))}</div>`}};
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
      ${screenHead('💎','Conquistas por Desafio','Cada hábito abre uma nova relíquia.','app')}
      <nav class="world-tabs achievement-tabs">${[['global','Total'],['aqua','Água'],['rat-tech','RAT Tech'],['reading','Leitura'],['screen-free','Sem Tela']].map(([id,label])=>`<button class="${current===id?'active':''}" data-achievement="${id}">${label}</button>`).join('')}</nav>
      <section class="achievement-summary"><div class="achievement-mascots ${current==='global'?'is-duo':''}"><img src="${current==='aqua'?ASSETS.aqua:current==='rat-tech'?ASSETS.rat:current==='reading'?ASSETS.reading:current==='screen-free'?ASSETS.offline:ASSETS.hero}" alt="Chalote celebrando conquistas" width="720" height="960">${current==='global'?`<img class="scarlote" src="${ASSETS.scarlote}" alt="Scarlote celebrando as conquistas globais" width="720" height="901">`:''}</div><div><small>${current==='global'?'GTI MISSIONS':current.toUpperCase()}</small><b>${unlocked}/${items.length} conquistas</b>${progressBar(pct(unlocked,items.length),'Conquistas desbloqueadas')}</div></section>
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
      ${screenHead('🔱','Progresso Total','Juntos por um amanhã mais saudável.','app')}
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
    const rows=await rpc('gti_missions_ranking_page',{p_challenge:current,p_period:range,p_offset:0});
    const avatars=await Promise.all((rows||[]).map(row=>avatarHtml(row.avatar_path,row.display_name,'small')));
    const cards=[];
    for(const row of rows||[]){
      const avatar=avatars[cards.length],medal=Number(row.rank)===1?'♛':Number(row.rank)===2?'♜':Number(row.rank)===3?'♝':row.rank;
      cards.push(`<article class="ranking-row rank-${Number(row.rank)} ${row.username===player.p.username?'me':''}"><strong>${medal}</strong><div class="ranking-user">${avatar}<div><button class="link-btn" data-member="${esc(row.username)}">${esc(row.display_name)}</button><small>@${esc(row.username)}${current==='global'?` • ${row.participating_challenges} mundo${Number(row.participating_challenges)===1?'':'s'}`:''}</small></div></div><span>${rankingScore(row,current)}${current!=='global'&&row.xp?`<small>${fmt(row.xp)} XP</small>`:''}</span></article>`);
    }
    const titles={global:['🏆','Ranking Geral','Todos os exploradores. Um futuro maior.'],aqua:['💧','Ranking da Água','Juntos por um amanhã mais saudável.'],'rat-tech':['⚡','Ranking RAT Tech','Mais movimento. Mais energia.'],reading:['▣','Ranking da Leitura','Mais livros. Mais horizontes.'],'screen-free':['♧','Ranking Sem Tela','Mais vida real. Mais bem-estar.']};
    const [icon,title,subtitle]=titles[current];
    app.innerHTML=shell(`<div class="ranking-screen">
      ${screenHead(icon,title,subtitle,'app')}
      <nav class="world-tabs ranking-world-tabs">${[['global','Geral'],['aqua','Água'],['rat-tech','RAT Tech'],['reading','Leitura'],['screen-free','Sem Tela']].map(([id,label])=>`<button class="${current===id?'active':''}" data-ranking-type="${id}">${label}</button>`).join('')}</nav>
      <nav class="period-tabs">${[['week','Esta semana'],['month','Este mês'],['all','Geral']].map(([id,label])=>`<button class="${range===id?'active':''}" data-ranking-period="${id}">${label}</button>`).join('')}</nav>
      ${current==='global'?`<section class="ranking-explainer has-scar"><span>✦</span><p>O ranking geral soma o XP dos desafios em que cada pessoa participa. Ninguém perde posição por não entrar em um mundo.</p><img src="${ASSETS.scarlote}" alt="Scarlote no ranking geral" width="720" height="901"></section>`:''}
      <div class="ranking-columns"><span>#</span><span>EXPLORADOR</span><span>${current==='global'?'XP':'PROGRESSO'}</span></div>
      <section class="ranking-list" id="rankingList">${cards.length?cards.join(''):'<div class="empty">Ainda não há progresso neste ranking.</div>'}</section><button class="secondary full" id="moreRanking" ${rows.length<20?'hidden':''}>Ver mais participantes</button>
      <blockquote>${current==='aqua'?'“Cada gole conta.”':current==='rat-tech'?'“Movimento hoje. Energia amanhã.”':current==='reading'?'“Grandes leitores constroem grandes futuros.”':current==='screen-free'?'“Menos tela. Mais do que realmente importa.”':'“A evolução fica maior quando é coletiva.”'}</blockquote>
    </div>`,'league');
    bindNav();
    let rankOffset=rows.length;
    const bindMembers=()=>document.querySelectorAll('[data-member]').forEach(b=>b.onclick=()=>nav('member',false,{username:b.dataset.member}));bindMembers();
    document.getElementById('moreRanking').onclick=async e=>{const b=e.currentTarget;b.disabled=true;try{const more=await rpc('gti_missions_ranking_page',{p_challenge:current,p_period:range,p_offset:rankOffset});rankOffset+=more.length;document.getElementById('rankingList').insertAdjacentHTML('beforeend',more.map(row=>`<article class="ranking-row"><strong>${row.rank}</strong><div class="ranking-user">${avatarFallback(row.display_name,'small')}<div><button class="link-btn" data-member="${esc(row.username)}">${esc(row.display_name)}</button><small>@${esc(row.username)}</small></div></div><span>${rankingScore(row,current)}</span></article>`).join(''));b.hidden=more.length<20;bindMembers();}catch(error){b.textContent='Não foi possível carregar. Tentar novamente';}finally{b.disabled=false;}};
    document.querySelectorAll('[data-ranking-type]').forEach(button=>button.onclick=()=>nav('league',false,{type:button.dataset.rankingType,period:range}));
    document.querySelectorAll('[data-ranking-period]').forEach(button=>button.onclick=()=>nav('league',false,{type:current,period:button.dataset.rankingPeriod}));
  }

  window.GTIUniverseUI={renderMerch,duoArtwork,playerProgress,renderHome,renderDashboard,renderChallenges,renderTech,renderReading,renderOffline,renderAchievements,renderProgress,renderLeague,brandLogo};
  render();
})();
