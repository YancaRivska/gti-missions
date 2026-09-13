# Solução de problemas

## Usuário não recebe XP

1. Confirme que a RPC retornou sucesso.
2. Verifique a entrada diária e `completed_at`.
3. Verifique o `event_key` em `gti_missions_xp_events`.
4. Confirme se o evento já existia; repetição válida não duplica XP.
5. Confira limites, termos e timezone.

## Streak não atualiza

1. Confirme evento de XP no dia, não apenas envio parcial.
2. Compare datas em `America/Sao_Paulo`.
3. Procure lacunas entre hoje/ontem e dias anteriores.
4. Execute a RPC de progresso com a sessão afetada em ambiente seguro.

## Foto não sobe

1. Confirme HTTPS e permissão de câmera.
2. Verifique sessão e expiração.
3. Confirme MIME e limite do bucket.
4. Confira path com `auth.uid()` e desafio correto.
5. Inspecione a policy de INSERT no Storage.
6. Se a RPC falhou, confirme remoção do arquivo órfão.

## Ranking divergente

Confira categoria, período, timestamps dos eventos e a métrica específica. O desempate usa métrica, XP e username.

## Admin sem acesso

Confira conta permanente, termos, linha em `gti_missions_admins` e retorno de `gti_missions_is_admin()`.

## Limpeza das fotos falha

Confira logs, variáveis do servidor, segredo/header do Cron, throttle, Storage e metadados nas três tabelas.
