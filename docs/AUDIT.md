# Auditoria de engenharia — 2026-09-12

Base auditada: `YancaRivska/gti-missions`, `main` em `e262794`. O design não foi alterado.

## Mapa

- HTML, CSS e JavaScript estáticos.
- Supabase Auth, PostgreSQL/RPC/RLS, Storage e Edge Functions.
- Vercel, PWA e fallback offline.
- Projeto Supabase compartilhado com GTI Click.

## Achados

| Prioridade | Estado | Achado | Tratamento |
| --- | --- | --- | --- |
| P0 | operação pendente | limpeza com `service_role` aceita chamada pública; Cron não envia segredo | código exige segredo; configurar ambiente/Vault, atualizar Cron e publicar |
| P0 | operação pendente | `publish-gti-missions-web` está pública e escreve com `service_role` | remover ou autenticar após confirmar que é legado |
| P1 | corrigido no Git | 28 migrations estavam no banco, mas não no repositório | histórico recuperado do banco ativo |
| P1 | corrigido no Git | progresso customizado podia perder incremento concorrente | lock transacional por usuário/desafio/dia |
| P1 | corrigido no Git | erro interno desconhecido era mostrado ao usuário | fallback genérico testado |
| P1 | painel pendente | proteção contra senhas vazadas desabilitada | habilitar no Supabase Auth |
| P2 | corrigido no Git | cinco policies reavaliavam Auth por linha | migration otimizada |
| P2 | corrigido no Git | não havia lint, testes, typecheck, build ou CI | controles e workflow adicionados |
| P2 | corrigido no Git | configuração/regras puras misturadas à UI | extração mínima e testada |
| P2 | documentado | `app.js` ainda reúne transporte, sessão e orquestração | reduzir incrementalmente sem reescrita |
| P3 | observado | índices recentes aparecem como não usados | não remover com amostra de apenas dois usuários |

## Validações

- Nenhuma `service_role`, private key ou senha real foi encontrada no Git.
- A chave visível é publicável e depende de RLS.
- XP é calculado no servidor e possui unicidade por usuário/evento.
- Admin é verificado no backend.
- Buckets são privados e usam ownership por path.
- Regras diárias usam `America/Sao_Paulo`.

Warnings genéricos de `SECURITY DEFINER` não são prova isolada de falha: várias RPCs precisam executar transações controladas e fazem autorização interna. Elas continuam exigindo `search_path` fixo e grants mínimos.
