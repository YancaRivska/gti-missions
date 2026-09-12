(() => {
  'use strict';

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

  function progressBar(value, label) {
    const safe = clamp(Number(value) || 0, 0, 100);
    return `<div class="game-progress" role="progressbar" aria-label="${label}" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.round(safe)}"><i style="--progress:${safe}%"></i></div>`;
  }

  function worldState(days, unlockAt, completeAt) {
    if (days >= completeAt) return 'completed';
    if (days >= unlockAt) return 'active';
    return 'locked';
  }

  function worldNode(world, days) {
    const state = worldState(days, world.unlockAt, world.completeAt);
    const icon = state === 'completed' ? '✓' : state === 'locked' ? '⌁' : '◆';
    const status = state === 'completed'
      ? 'Concluído'
      : state === 'locked'
        ? `Libera com ${world.unlockAt} dias`
        : `${days}/${world.completeAt} dias`;
    return `<button class="world-node world-${world.order} ${state}" type="button" data-world-state="${state}" aria-label="${world.title}: ${status}"><span class="world-marker">${icon}</span><span class="world-copy"><small>MUNDO ${world.order}</small><b>${world.title}</b><em>${status}</em></span></button>`;
  }

  function missionCard({ icon, title, description, progress, progressText, reward, done }) {
    return `<article class="aqua-mission ${done ? 'done' : ''}"><span class="mission-medal">${icon}</span><div><b>${title}</b><p>${description}</p>${progressBar(progress, `${title}: ${progressText}`)}<small>${progressText}</small></div><span class="mission-reward">${done ? '✓' : reward}</span></article>`;
  }

  function achievement({ icon, title, description, unlocked, rare = false }) {
    return `<article class="achievement-tile ${unlocked ? 'unlocked' : 'locked'} ${rare ? 'rare' : ''}"><span>${unlocked ? icon : '⌁'}</span><div><b>${title}</b><small>${description}</small></div><em>${unlocked ? 'Conquistado' : 'Bloqueado'}</em></article>`;
  }

  async function render(ctx) {
    const {
      app, s, p, u, avatar, fmt, esc, shell, bindNav, rpc,
      uploadCheckinPhoto, discardCheckinPhoto, bindProofCamera,
      renderAqua, level, levelName,
    } = ctx;

    const target = Math.max(1, Number(s.water_target_ml) || 2000);
    const today = Math.max(0, Number(s.water_today_ml) || 0);
    const todayPct = clamp(Math.round((today / target) * 100), 0, 100);
    const weekDays = clamp(Number(s.water_week_days) || 0, 0, 7);
    // A ofensiva conta dias em que o player conquistou XP, mesmo antes de fechar a meta.
    const streak = Math.max(0, Number(s.activity_streak) || 0);
    const totalXp = Math.max(0, Number(s.total_xp) || 0);
    const currentLevel = level(totalXp);
    const levelPct = clamp(((totalXp % 500) / 500) * 100, 0, 100);
    const worlds = [
      { order: 1, title: 'Costa da Hidratação', unlockAt: 0, completeAt: 2 },
      { order: 2, title: 'Floresta do Equilíbrio', unlockAt: 2, completeAt: 4 },
      { order: 3, title: 'Ilha da Vitalidade', unlockAt: 4, completeAt: 6 },
      { order: 4, title: 'Montanha Gelada', unlockAt: 6, completeAt: 7 },
    ];

    const missions = [
      missionCard({ icon: '🥤', title: 'Primeiro registro do dia', description: 'Registre sua primeira água.', progress: today > 0 ? 100 : 0, progressText: today > 0 ? '1/1 concluído' : '0/1 registro', reward: '+5 XP', done: today > 0 }),
      missionCard({ icon: '💧', title: 'Alcançar a meta de hoje', description: `${fmt(today)} de ${fmt(target)} ml`, progress: todayPct, progressText: `${todayPct}% concluído`, reward: '+50 XP', done: todayPct >= 100 }),
      missionCard({ icon: '🧭', title: 'Explorar os 7 marcos', description: 'Complete a meta em todos os dias da semana.', progress: (weekDays / 7) * 100, progressText: `${weekDays}/7 dias`, reward: '+100 XP', done: weekDays >= 7 }),
      missionCard({ icon: '🔥', title: 'Manter a ofensiva', description: 'Volte amanhã e mantenha o ritmo.', progress: Math.min(100, (streak / 7) * 100), progressText: `${streak} dia${streak === 1 ? '' : 's'} de sequência`, reward: 'ATIVA', done: streak >= 7 }),
    ].join('');

    const achievements = [
      achievement({ icon: '💧', title: 'Primeiro Gole', description: 'Faça um registro de água.', unlocked: today > 0 || weekDays > 0 || streak > 0 }),
      achievement({ icon: '🏅', title: 'Meta Dominada', description: 'Alcance 100% da meta diária.', unlocked: todayPct >= 100 }),
      achievement({ icon: '🌊', title: 'Explorador da Maré', description: 'Complete 3 dias nesta semana.', unlocked: weekDays >= 3 }),
      achievement({ icon: '🔥', title: 'Ofensiva 7', description: 'Mantenha uma sequência de 7 dias.', unlocked: streak >= 7, rare: true }),
      achievement({ icon: '🧊', title: 'Guardião da Semana', description: 'Feche o desafio AquaXP 7/7.', unlocked: weekDays >= 7, rare: true }),
      achievement({ icon: '⚡', title: 'Explorador Veterano', description: 'Alcance o nível 5 no GTI Missions.', unlocked: currentLevel >= 5 }),
    ].join('');

    const runes = Array.from({ length: 7 }, (_, index) => `<i class="${index < weekDays ? 'done' : index === weekDays ? 'current' : ''}"><span>${index + 1}</span></i>`).join('');
    const customAmount = clamp(Number(p.water_container_ml) || 475, 50, 2000);

    app.innerHTML = shell(`
      <div class="water-game">
        <header class="aquaxp-screen-head">
          <button class="screen-back" data-nav="challenges" aria-label="Voltar">‹</button>
          <div><h1><span>💧</span> Desafio da Água</h1><p>Hidratação hoje. Mais conquistas amanhã.</p></div>
          <button class="screen-alert" data-nav="profile" aria-label="Abrir perfil">${avatar}</button>
        </header>

        <section class="aquaxp-status-row">
          <div><span>🔥</span><b>${streak}</b><small>dias seguidos</small></div>
          <div><span>⚡</span><b>${fmt(totalXp)}</b><small>XP total</small></div>
        </section>

        <nav class="water-tabs" role="tablist" aria-label="Áreas do Desafio da Água">
          <button class="active" type="button" role="tab" aria-selected="true" data-water-tab="map">Mapa</button>
          <button type="button" role="tab" aria-selected="false" data-water-tab="missions">Missões</button>
          <button type="button" role="tab" aria-selected="false" data-water-tab="achievements">Conquistas</button>
        </nav>

        <div class="water-tab-panel" role="tabpanel" data-water-panel="map">
          <section class="adventure-map" aria-label="Mapa da jornada semanal AquaXP">
            <div class="map-atmosphere"></div>
            <img class="map-chalote" src="/assets/challenges/aquaxp/chalote-aquaxp-v1.webp" alt="Chalote explorando o mapa AquaXP" width="720" height="960">
            <div class="map-heading"><span>AQUAXP LEAGUE • JORNADA DA SEMANA</span><b>${weekDays}/7 marcos</b></div>
            ${worlds.map(world => worldNode(world, weekDays)).join('')}
            <div class="map-legend"><span><i class="completed"></i>Concluído</span><span><i class="active"></i>Atual</span><span><i class="locked"></i>Bloqueado</span></div>
            <div class="map-daily-progress"><span>Meta diária</span><b>${fmt(today)} / ${fmt(target)} ml</b><em>${todayPct}%</em>${progressBar(todayPct,'Meta diária de hidratação')}</div>
            <button class="game-cta aurora" id="continueJourney" type="button">Registrar água →</button>
          </section>

          <section class="today-voyage game-panel">
            <div class="section-heading"><div><small>MISSÃO DE HOJE</small><h2>Encha o reservatório</h2></div><strong>${todayPct}%</strong></div>
            <div class="water-meter" role="progressbar" aria-label="Meta de água de hoje" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${todayPct}"><div style="--water-level:${todayPct}%"><span></span></div></div>
            <div class="meter-copy"><b>${fmt(today)} ml</b><span>de ${fmt(target)} ml</span></div>
          </section>

          <section class="guardian-card">
            <div class="guardian-copy"><small>DESAFIO DO GUARDIÃO</small><h2>Domine os sete marcos</h2><p>Complete sua meta diária durante toda a semana e libere o selo AquaXP.</p></div>
            <div class="rune-progress" aria-label="${weekDays} de 7 dias concluídos">${runes}</div>
            <div class="guardian-reward"><span>RECOMPENSA</span><b>🏅 Selo AquaXP</b><strong>+100 XP</strong></div>
          </section>
        </div>

        <div class="water-tab-panel" role="tabpanel" data-water-panel="missions" hidden>
          <section class="mission-board game-panel">
            <div class="section-heading"><div><small>OBJETIVOS REAIS</small><h2>Missões de hoje</h2></div><span>${todayPct >= 100 ? 'Meta concluída' : 'Em andamento'}</span></div>
            <div class="mission-list">${missions}</div>
          </section>
        </div>

        <div class="water-tab-panel" role="tabpanel" data-water-panel="achievements" hidden>
          <section class="achievement-board game-panel">
            <div class="section-heading"><div><small>COLEÇÃO</small><h2>Conquistas</h2></div><span>${Number(s.badges) || 0} selo${Number(s.badges) === 1 ? '' : 's'}</span></div>
            <div class="achievement-grid">${achievements}</div>
          </section>
        </div>

        <section class="water-check game-panel" id="waterCheck">
          <div class="quest-banner"><span>CHECK-IN DA MISSÃO</span><b>Registre sua água</b><p>Primeiro tire a foto. Depois escolha a quantidade.</p></div>
          <div class="camera-proof aqua-camera">
            <div class="section-row"><div><b>Foto da água</b><p>Tirada agora pelo app. A imagem fica privada e desaparece após 24 horas.</p></div><span class="proof-required">OBRIGATÓRIA</span></div>
            <button class="game-cta cyan full" id="openCamera" type="button">📷 Abrir câmera</button>
            <div id="cameraMount"></div><div id="cameraMsg"></div>
          </div>
          <div class="amount-picker">
            <div class="section-heading"><div><small>QUANTIDADE</small><h2>Quanto você bebeu?</h2></div><span>Hoje: ${fmt(today)} ml</span></div>
            <div class="water-presets">${[200, 250, 300, 350, 475, 500, 750].map(amount => `<button type="button" data-water="${amount}"><span>+</span><b>${amount}</b><small>ml</small></button>`).join('')}<button type="button" data-water="${customAmount}"><span>+</span><b>${customAmount}</b><small>${esc(p.water_container_label || 'Recipiente')}</small></button></div>
            <form class="custom-water game-custom-water" id="customWater"><label>Outro valor (ml)<input id="customMl" type="number" min="50" max="2000" step="1" inputmode="numeric" placeholder="Ex.: 425"></label><button class="game-cta cyan" type="submit">Registrar</button></form>
            <div id="msg" aria-live="polite"></div>
          </div>
        </section>
      </div>
    `, 'aqua');

    bindNav();
    const proof = bindProofCamera();
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    document.querySelectorAll('[data-water-tab]').forEach(button => {
      button.onclick = () => {
        const targetPanel = button.dataset.waterTab;
        document.querySelectorAll('[data-water-tab]').forEach(tab => {
          const active = tab === button;
          tab.classList.toggle('active', active);
          tab.setAttribute('aria-selected', String(active));
        });
        document.querySelectorAll('[data-water-panel]').forEach(panel => {
          panel.hidden = panel.dataset.waterPanel !== targetPanel;
        });
      };
    });

    document.querySelectorAll('[data-world-state="active"], #continueJourney, #quickWaterRegister').forEach(button => {
      button.onclick = () => document.getElementById('waterCheck').scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'start' });
    });

    async function logWater(amount) {
      const message = document.getElementById('msg');
      let path = null;
      if (!proof.blob) {
        message.innerHTML = '<div class="notice quest-notice">Tire uma foto da água antes de registrar.</div>';
        document.getElementById('openCamera').focus();
        return;
      }

      const controls = document.querySelectorAll('[data-water], #customWater button');
      controls.forEach(control => { control.disabled = true; });
      message.innerHTML = '<div class="notice quest-notice">Enviando a prova e atualizando sua jornada...</div>';

      try {
        path = await uploadCheckinPhoto(proof.blob, u.id, 'aqua');
        const result = await rpc('gti_missions_log_water', { p_amount_ml: Number(amount), p_photo_path: path });
        const reward = Number(result?.xp_awarded) || 0;
        message.innerHTML = `<div class="success xp-toast"><b>Missão atualizada</b><span>+${fmt(amount)} ml${reward ? ` • +${fmt(reward)} XP` : ''}</span><small>Foto protegida por 24 horas.</small></div>`;
        setTimeout(() => renderAqua(), reducedMotion ? 150 : 700);
      } catch (error) {
        if (path) await discardCheckinPhoto(path);
        controls.forEach(control => { control.disabled = false; });
        message.innerHTML = `<div class="notice quest-notice">${esc(ctx.friendly(error))}</div>`;
      }
    }

    document.querySelectorAll('[data-water]').forEach(button => {
      button.onclick = () => logWater(button.dataset.water);
    });
    document.getElementById('customWater').onsubmit = event => {
      event.preventDefault();
      const amount = Number(document.getElementById('customMl').value);
      if (amount) logWater(amount);
    };
  }

  window.GTIWaterGame = { render };
})();
