const test = require('node:test');
const assert = require('node:assert/strict');
const domain = require('../core/domain.js');

test('calcula níveis nos limites de XP', () => {
  assert.equal(domain.calculateLevel(-1), 1);
  assert.equal(domain.calculateLevel(0), 1);
  assert.equal(domain.calculateLevel(499), 1);
  assert.equal(domain.calculateLevel(500), 2);
  assert.equal(domain.getLevelName(2500), 'Legend');
});

test('calcula referência de água com limites do produto', () => {
  assert.equal(domain.calculateSuggestedWater(20), 1500);
  assert.equal(domain.calculateSuggestedWater(70), 2450);
  assert.equal(domain.calculateSuggestedWater(200), 4000);
  assert.equal(domain.calculateSuggestedWater(null), null);
});

test('calcula IMC sem aceitar medidas ausentes', () => {
  assert.equal(domain.calculateBmi(0, 70), null);
  assert.equal(domain.calculateBmi(170, 70).toFixed(1), '24.2');
  assert.equal(domain.getBmiReference(24.2), 'Faixa de referência geral');
});

test('escapa conteúdo controlado por usuários', () => {
  assert.equal(domain.escapeHtml('<img src=x onerror="x">'), '&lt;img src=x onerror=&quot;x&quot;&gt;');
});

test('não expõe erro técnico desconhecido ao usuário', () => {
  const output = domain.getUserSafeError(new Error('relation private_table does not exist'));
  assert.equal(output, 'Não foi possível concluir sua solicitação.');
});
