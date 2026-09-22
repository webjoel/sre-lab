# Fase 4 — Plataforma: identidade, segredos, políticas e entrada de tráfego

Tudo instalado pelo ArgoCD (app-of-apps), com sync waves definindo a ordem.

## Componentes

| Onda | Componente | Papel |
|---|---|---|
| 0 | cert-manager | CA interna do lab; emite os certificados de todo o resto |
| 0 | Envoy Gateway | Implementação da Gateway API (entrada de tráfego) |
| 1 | Keycloak | Provedor de identidade: OIDC para Grafana, ArgoCD e a API |
| 1 | Vault + External Secrets Operator | Segredos fora do Git, sincronizados como Secrets do Kubernetes |
| 1 | Kyverno | Policy as code no admission |
| 2 | CloudNativePG + PgBouncer | Postgres operado: réplica, failover, pool de conexões, backup |
| 2 | KEDA | Autoscaling pelo tamanho da fila |

## Keycloak: identidade

Um realm `sre-lab` com três clientes e alguns usuários de teste (um admin, um leitor).

**1. SSO nas ferramentas.** Grafana e ArgoCD passam a autenticar por OIDC, com o grupo do usuário
definindo o papel: `sre-admins` vira admin, `sre-viewers` vira somente leitura. É o mesmo desenho que
empresas usam com Okta, Entra ID ou Google Workspace, e resolve a pergunta "como você controla quem
pode dar sync em produção".

**2. API protegida.** A `order-api` passa a exigir um token JWT: valida assinatura pelo JWKS do Keycloak,
confere `exp`, `aud` e `iss`. O k6 pega um token antes de gerar carga (fluxo client credentials).

**3. O que isso ensina (e cai em entrevista):**
- Diferença entre autenticação e autorização, e entre OAuth 2.0 e OIDC
- Por que validar JWT localmente pelo JWKS é melhor que consultar o IdP a cada requisição
- Rotação de chave de assinatura sem derrubar a aplicação
- O incidente clássico: certificado ou chave expirada derrubando o login de todo mundo

**Exercício de incidente:** expire a chave do realm e observe o efeito em cascata — Grafana e ArgoCD
recusando login, API devolvendo 401 em massa. Diagnostique pelos logs e pelo `openssl`.

## Entrada de tráfego: Ingress e Gateway API lado a lado

O recurso **Ingress** é o que você mais encontra em produção hoje, mas a implementação mais comum
(ingress-nginx da comunidade Kubernetes) está sendo descontinuada. A sucessora oficial é a
**Gateway API**. O lab pratica os dois, em sequência:

**Etapa 1 — Ingress clássico.** Exponha a `order-api` com um recurso `Ingress`: host, path, TLS via
cert-manager, e as anotações que todo mundo usa (rewrite, timeouts, rate limit, CORS).
Note que essas anotações são específicas do controller e não são portáveis.

**Etapa 2 — HTTPRoute.** Migre para Gateway API: um `GatewayClass`, um `Gateway` (que o time de
plataforma administra) e uma `HTTPRoute` por aplicação (que o time da aplicação administra).
Sem anotações: filtros, timeouts e split de tráfego são campos do próprio recurso.

**Etapa 3 — Compare e documente** em um ADR:

| | Ingress | Gateway API |
|---|---|---|
| Configuração avançada | Anotações do controller | Campos do próprio recurso |
| Portabilidade entre controllers | Baixa | Alta |
| Separação de responsabilidades | Um recurso só | Gateway (plataforma) x HTTPRoute (aplicação) |
| Split de tráfego por peso | Só com anotação | Nativo, e é o que o Argo Rollouts usa no canary |
| Maturidade no mercado | Presente em quase todo lugar | Adoção crescente |

Saber explicar essa transição vale numa entrevista: mostra que você acompanha a direção do ecossistema
sem descartar o que está em produção.

## Exercícios da fase

1. Login no Grafana e no ArgoCD via Keycloak; um usuário do grupo de leitura não consegue dar sync.
2. Token JWT obrigatório na API; k6 ajustado para obter o token.
3. Ingress funcionando, depois HTTPRoute com o mesmo comportamento, e o ADR comparando.
4. Segredo do banco saindo do Vault via ExternalSecret, sem nada sensível no Git.
5. Política do Kyverno bloqueando pod sem `requests`/`limits` — e um PR que falha por causa dela.
6. Failover do Postgres: derrube o primário e meça quanto tempo a aplicação leva para voltar.
7. Disaster recovery: configure o backup contínuo para o S3 do LocalStack e execute os cenários de
   `disaster-recovery.md`, registrando RTO e RPO medidos.
