# GTI Missions

Plataforma web gamificada da comunidade Galera do TI para hábitos, missões, XP, níveis, selos e rankings.

Produção: <https://gti-missions-yanca-rivska.vercel.app/>

## Stack

- Frontend estático em HTML, CSS e JavaScript, publicado na Vercel.
- Supabase Auth para contas permanentes e recuperação de senha.
- PostgreSQL/Supabase para regras transacionais, XP, streak, ranking e administração.
- Supabase Storage privado para avatares e provas temporárias.
- Supabase Edge Function e Cron para retenção de provas por 24 horas.
- PWA com Service Worker e fallback offline básico.

## Desenvolvimento

```bash
npm ci
npx serve .
```

Use uma origem HTTP. Câmera, autenticação e Service Worker não funcionam corretamente por `file://`.

## Qualidade

```bash
npm run lint
npm run typecheck
npm test
npm run build
npm run check
```

`npm run check` é obrigatório antes de pull request ou deploy. O CI executa a mesma sequência na `main` e em pull requests.

## Configuração

O frontend usa somente a URL e a chave **publicável** do Supabase, centralizadas em `config.js`. Segredos existem apenas nos ambientes de servidor.

| Variável | Uso | Exposição permitida |
| --- | --- | --- |
| `SUPABASE_URL` | Endpoint do projeto | servidor; a URL também pode ser pública |
| `SUPABASE_PUBLISHABLE_KEY` | Cliente público | frontend |
| `SUPABASE_SERVICE_ROLE_KEY` | Rotina de limpeza | somente Edge Function |
| `GTI_MISSIONS_CLEANUP_SECRET` | Autoriza o Cron | somente Edge Function/Vault |

Copie `.env.example` apenas para serviços locais. Nunca versione `.env` nem valores reais.

## Banco e migrations

Os arquivos em `supabase/migrations/` representam o histórico aplicado. Toda mudança estrutural deve ser uma migration revisável; não altere o banco manualmente.

Antes de aplicar: faça backup, valide em branch/local, execute os testes, aplique, rode os advisors e faça smoke test.

## Deploy

A Vercel publica a raiz do repositório, sem compilação. `vercel.json` define cache, CSP e demais cabeçalhos.

A Edge Function de limpeza só deve ser publicada depois de configurar `GTI_MISSIONS_CLEANUP_SECRET` e atualizar o Cron para enviar `x-gti-cleanup-secret`. A mudança precisa ser coordenada para não interromper a retenção.

## Estrutura

```text
core/                 regras puras e reutilizáveis
test/                 testes unitários
scripts/              controles de qualidade e build
supabase/migrations/  evolução reproduzível do banco
supabase/functions/   serviços privilegiados de servidor
assets/               identidade visual aprovada
app.js                autenticação, API, perfil e orquestração
universe-ui.js        telas dos mundos e rankings
water-game.js         experiência AquaXP
style.css             apresentação visual aprovada
```

Leia também: [Arquitetura](docs/ARCHITECTURE.md), [Segurança](docs/SECURITY.md), [Auditoria](docs/AUDIT.md) e [Solução de problemas](docs/TROUBLESHOOTING.md).

## Versionamento

- Semantic Versioning para releases.
- Conventional Commits para histórico.
- Branches curtas: `feature/*`, `fix/*`, `refactor/*`.
- Mudanças pequenas e com uma intenção por commit.
