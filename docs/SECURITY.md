# Segurança

Todo dado do navegador é não confiável. A chave publicável pode aparecer no frontend; `service_role`, segredos de Cron e credenciais privadas jamais podem aparecer nele.

RPCs sensíveis devem validar `auth.uid()`, rejeitar usuário anônimo, verificar ownership/admin, calcular XP no servidor, usar chaves idempotentes, fixar `search_path` e revogar execução de `public` e `anon`.

## Operações obrigatórias

1. Configure `GTI_MISSIONS_CLEANUP_SECRET` na Edge Function.
2. Guarde o mesmo valor no Vault e faça o Cron enviar `x-gti-cleanup-secret`.
3. Publique a função e teste chamadas autorizada e não autorizada.
4. Remova ou proteja as funções legadas `gti-missions-live` e `publish-gti-missions-web`; a segunda usa `service_role`.
5. Habilite proteção contra senhas vazadas no Supabase Auth.
6. Revise separadamente os avisos do GTI Click, pois os produtos compartilham o projeto.

Se um segredo aparecer no Git, considere-o comprometido: rotacione primeiro e depois limpe o histórico.

Logs devem registrar categoria, operação e correlação, sem senha, JWT, refresh token, chave ou conteúdo de foto.
