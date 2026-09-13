# GTI Missions

Aplicativo web mobile-first da comunidade Galera do TI para missões mensais, hábitos, XP, níveis, emblemas e ranking.

Produção: <https://gti-missions-yanca-rivska.vercel.app/>

## Funcionalidades

- AquaXP com recipientes configuráveis, conclusão automática da meta e sem envio de evidência.
- RAT Tech com confirmação antes de concluir o treino e frequência semanal configurável.
- Temporadas mensais configuradas no Supabase, com código opcional, XP mensal e histórico permanente.
- 30 emblemas de água e 30 de treino, incluindo conquistas secretas e compartilhamento em Story ou formato quadrado.
- Ranking mensal paginado, comunidade e perfis públicos com controles de privacidade.
- Meu Diário com notas curtas privadas por padrão e publicação opcional.
- Desafios criados pela administração e exibidos sem alterar o frontend.
- Foto de perfil opcional em bucket privado; imagens são reduzidas no navegador antes do envio.
- Ofensiva calculada no servidor com calendário consistente em `America/Sao_Paulo`.
- Login, PWA e modo offline básico.

## Arquitetura

O frontend é estático e não possui dependências de runtime. O Supabase concentra Auth, Postgres, RLS, Storage de avatar e operações transacionais de progressão. A Vercel publica o conteúdo gerado em `dist/`.

A chave presente no frontend é somente a chave pública/publishable. Segredos administrativos e códigos de temporada não são enviados ao cliente.

## Desenvolvimento e validação

```bash
npm install
npm run check
```

`npm run check` executa lint, checagem de tipos, testes automatizados e o build de produção. Para servir a aplicação localmente:

```bash
npm run build
npx serve dist
```

As alterações de banco ficam em `supabase/migrations/`; os testes transacionais ficam em `supabase/tests/`.

## Deploy

A Vercel executa `npm run build` e publica `dist/`. O arquivo `vercel.json` mantém os cabeçalhos de segurança e o endpoint `/api/health`.

O antigo fluxo de fotos de evidência foi removido. O bucket de avatar continua privado e funcional.
