(function exposeDomain(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.GTIDomain = Object.freeze(api);
})(typeof window === 'undefined' ? null : window, () => {
  'use strict';

  const LEVEL_NAMES = Object.freeze(['Ping', 'Commit', 'Build', 'Deploy', 'Scale', 'Legend']);
  const XP_PER_LEVEL = 500;

  const escapeHtml = value => String(value ?? '').replace(
    /[&<>'"]/g,
    character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character],
  );

  const formatNumber = value => Number(value || 0).toLocaleString('pt-BR', { maximumFractionDigits: 2 });
  const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, value));
  const calculateLevel = xp => Math.floor(Math.max(0, Number(xp) || 0) / XP_PER_LEVEL) + 1;
  const getLevelName = xp => LEVEL_NAMES[Math.min(calculateLevel(xp) - 1, LEVEL_NAMES.length - 1)];

  function calculateBmi(heightCm, weightKg) {
    const heightMetres = Number(heightCm) / 100;
    const weight = Number(weightKg);
    if (!heightMetres || !weight || heightMetres <= 0) return null;
    return weight / (heightMetres * heightMetres);
  }

  function getBmiReference(value) {
    if (!value) return 'Preencha altura e peso';
    if (value < 18.5) return 'Abaixo da faixa de referência';
    if (value < 25) return 'Faixa de referência geral';
    if (value < 30) return 'Acima da faixa de referência';
    return 'Bem acima da faixa de referência';
  }

  function calculateSuggestedWater(weightKg) {
    const weight = Number(weightKg);
    if (!weight) return null;
    return Math.round(clamp(weight * 35, 1500, 4000) / 25) * 25;
  }

  function getUserSafeError(error) {
    const message = String(error?.message || '').toLowerCase();
    if (message.includes('invalid login')) return 'E-mail ou senha inválidos.';
    if (message.includes('email not confirmed')) return 'Confirme seu e-mail antes de entrar.';
    if (message.includes('rate limit')) return 'Muitas tentativas. Tente novamente mais tarde.';
    if (message.includes('duplicate') || error?.code === '23505') return 'Esse @username já está em uso.';
    if (message.includes('terms')) return 'Atualize e aceite os Termos para continuar.';
    if (message.includes('admin required')) return 'Essa ação é exclusiva da administração.';
    if (message.includes('camera proof required')) return 'Tire uma foto agora para validar o check.';
    if (message.includes('invalid or expired camera proof')) return 'A foto do check não foi validada. Tire outra foto agora.';
    if (message.includes('permission denied') && message.includes('camera')) return 'Permita o acesso à câmera para fazer o check.';
    if (message.includes('daily logging limit') || message.includes('daily value limit')) return 'O limite de registros de hoje foi atingido.';
    return 'Não foi possível concluir sua solicitação.';
  }

  return {
    XP_PER_LEVEL,
    escapeHtml,
    formatNumber,
    clamp,
    calculateLevel,
    getLevelName,
    calculateBmi,
    getBmiReference,
    calculateSuggestedWater,
    getUserSafeError,
  };
});
