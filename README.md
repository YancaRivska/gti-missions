# GTI Missions

Aplicativo web da comunidade Galera do TI para missões, hábitos, XP, selos e ranking mensal.

Produção: <https://gti-missions-yanca-rivska.vercel.app/>

## Funcionalidades

- AquaXP com meta fixa de 7 dias por semana.
- Tech Rat com frequência configurável de 3 a 7 dias.
- Novos desafios publicados pela administração e exibidos automaticamente para a comunidade.
- Check de desafios com foto capturada pela câmera e retenção máxima de 24 horas.
- Foto de perfil anexada da galeria ou capturada pela câmera, armazenada em bucket privado e exibida somente para participantes autenticados.
- Ofensiva calculada pelos dias consecutivos em que o player conquistou XP.
- Login, perfil, ranking, PWA e modo offline básico.

## Arquitetura

O frontend é estático (`index.html`, `app.js` e `style.css`) e é publicado na Vercel. Autenticação, banco, RPCs, RLS, Storage e a limpeza automática das fotos usam Supabase.

O projeto Supabase ativo já está provisionado. A chave presente no frontend é a chave pública/publishable; chaves administrativas nunca devem ser adicionadas ao repositório.

## Desenvolvimento local

Sirva esta pasta com qualquer servidor HTTP estático. Por exemplo:

```bash
npx serve .
```

Não abra `index.html` diretamente via `file://`, pois autenticação, Service Worker e câmera dependem de uma origem HTTP segura.

## Deploy

A Vercel publica automaticamente a raiz deste repositório a cada atualização da branch `main`, sem comando de build e sem diretório de saída. O arquivo `vercel.json` configura os cabeçalhos de segurança e `/api/health`.

## Supabase

A função agendada de limpeza está em `supabase/functions/cleanup-gti-missions-checkins`. No ambiente ativo, o Cron executa a função a cada hora e remove provas com mais de 24 horas.