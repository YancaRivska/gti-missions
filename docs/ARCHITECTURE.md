# Arquitetura

O GTI Missions é um frontend estático. A interface chama Auth, REST, RPCs e Storage do Supabase diretamente com a chave publicável e o JWT do usuário. RLS, constraints e funções PostgreSQL são a fronteira confiável.

| Camada | Responsabilidade | Onde diagnosticar |
| --- | --- | --- |
| UI | renderização e eventos | `app.js`, `universe-ui.js`, `water-game.js`, `style.css` |
| Domínio puro | nível, IMC, hidratação e saída segura | `core/domain.js` |
| Cliente de dados | sessão, REST, RPC e Storage | início de `app.js` |
| Backend | XP, streak, limites, badges, ranking e admin | RPCs nas migrations |
| Banco | ownership, unicidade, consistência e idempotência | constraints e RLS |
| Retenção | exclusão de provas vencidas | Edge Function de limpeza |
| Infraestrutura | cache, CSP, deploy e saúde | `vercel.json`, `sw.js`, `health.json` |

## Fluxo

1. Usuário cria conta ou entra pelo Supabase Auth.
2. Perfil é criado/atualizado com aceite dos termos.
3. Rotas funcionais exigem conta permanente e termos atuais.
4. Usuário entra no desafio quando necessário.
5. UI envia a ação, nunca um valor livre de XP.
6. RPC valida identidade, perfil, desafio, limites, data e prova.
7. RPC registra progresso e cria XP idempotente.
8. Ranking lê os eventos ou métricas oficiais no banco.

## Fontes de verdade

- XP: `gti_missions_xp_events`; o cliente não escreve nessa tabela.
- Streak: calculado no banco em `America/Sao_Paulo`.
- Ranking: `gti_missions_leaderboard` e `gti_missions_challenge_leaderboard`.
- Missão diária: unicidade por usuário, desafio e dia.
- Admin: `gti_missions_admins`, verificada dentro das RPCs.
- Fotos: buckets privados; paths começam pelo `auth.uid()`.

O navegador serve apenas para apresentação de datas. Não use o relógio do dispositivo como fonte de verdade para XP, streak, conclusão ou reset diário.

O frontend continua intencionalmente simples e sem bundler. `app.js` ainda concentra sessão, transporte e alguma orquestração; novas extrações devem ser incrementais e protegidas por testes.
