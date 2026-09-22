# Análise de requisitos de vagas SRE / DevOps / Platform

> **Fonte:** `requisitos_SRE.txt`, arquivo original com os requisitos das vagas analisadas.
> **Base de cálculo:** **38 blocos de requisitos identificáveis** no arquivo.
> **Representatividade:** percentual de blocos/vagas em que o requisito aparece pelo menos uma vez.
> **Regra de contagem:** cada requisito é contado no máximo uma vez por bloco, mesmo quando aparece repetidamente no mesmo bloco.
> **Normalização:** foram agrupadas somente variações claramente equivalentes de escrita (ex.: `ArgoCD`/`Argo CD`, `Golang`/`Go`, `GitLab CI`/`GitLab CI/CD`). Tecnologias e serviços específicos permanecem separados.
> **Importante:** a base textual fornecida contém **38 blocos**, embora o levantamento tenha sido descrito anteriormente como aproximadamente 40 vagas. Para manter a análise auditável, os percentuais desta versão usam exclusivamente os 38 blocos presentes no arquivo.

## Tabela completa

| Descrição | Temática | Percentual de representatividade |
|---|---|---:|
| **Observabilidade / Monitoramento / APM** — Monitoramento e observabilidade de infraestrutura, aplicações, bancos, redes, containers e cloud. | Observabilidade e Telemetria | **76.3%** |
| **Automação** — Automação operacional, provisionamento, ferramentas e redução de toil. | Automação & Plataforma | **60.5%** |
| **AWS** — Experiência com a plataforma AWS e seus serviços de compute, storage, networking e security. | Cloud & Infraestrutura | **60.5%** |
| **CI/CD** — Pipelines de integração, entrega/deploy e automação do ciclo de software. | CI/CD & GitOps | **57.9%** |
| **Terraform** — Infrastructure as Code, módulos, versionamento, state e automação. | Automação & Plataforma | **55.3%** |
| **Kubernetes** — Orquestração, operação de clusters, workloads, scaling, troubleshooting e confiabilidade. | Container & Orquestração | **52.6%** |
| **Grafana** — Dashboards, visualização e alertas. | Observabilidade e Telemetria | **44.7%** |
| **Containers / Containerização** — Arquitetura e operação de workloads baseados em containers. | Container & Orquestração | **42.1%** |
| **Troubleshooting** — Investigação e diagnóstico de falhas. | Resiliência e Operação | **42.1%** |
| **Networking / TCP-IP** — Redes, conectividade, TCP/IP, subnets, rotas e controles de tráfego. | Cloud & Infraestrutura | **39.5%** |
| **Python** — Automação operacional, scripting e desenvolvimento de ferramentas. | Automação & Plataforma | **39.5%** |
| **GCP** — Google Cloud Platform e seus serviços. | Cloud & Infraestrutura | **36.8%** |
| **Segurança / DevSecOps / Hardening** — Segurança de infraestrutura/cloud, hardening e DevSecOps. | Segurança & Compliance | **36.8%** |
| **Azure** — Microsoft Azure e ambientes corporativos/cloud. | Cloud & Infraestrutura | **31.6%** |
| **Linux** — Administração, troubleshooting, servidores, comandos e hardening Linux. | Resiliência e Operação | **31.6%** |
| **Prometheus** — Métricas e séries temporais. | Observabilidade e Telemetria | **31.6%** |
| **Produção** — Operação e sustentação de ambientes produtivos. | Resiliência e Operação | **28.9%** |
| **Comunicação / Stakeholders** — Comunicação técnica, colaboração e interação com stakeholders. | Outros | **26.3%** |
| **Datadog** — Observabilidade, APM, métricas, logs e alertas. | Observabilidade e Telemetria | **26.3%** |
| **Docker** — Construção, execução, otimização de imagens e operação de containers. | Container & Orquestração | **26.3%** |
| **GitHub** — Repositórios e colaboração de desenvolvimento. | CI/CD & GitOps | **26.3%** |
| **GitHub Actions** — Workflows e pipelines de CI/CD. | CI/CD & GitOps | **26.3%** |
| **Incidentes / On-call / Postmortem** — Gestão de incidentes, plantão, análise pós-incidente e recuperação. | Resiliência e Operação | **26.3%** |
| **SRE** — Práticas de engenharia de confiabilidade e SRE. | Resiliência e Operação | **26.3%** |
| **Argo CD** — GitOps e entrega contínua. | CI/CD & GitOps | **23.7%** |
| **Bash / Shell Script** — Automação e scripts operacionais. | Automação & Plataforma | **23.7%** |
| **Git** — Versionamento, branches, commits, pull requests e revisão de código. | CI/CD & GitOps | **23.7%** |
| **IAM** — Identity and Access Management. | Segurança & Compliance | **23.7%** |
| **Load Balancer / ALB / NLB** — Balanceamento de carga e componentes de entrada de tráfego. | Cloud & Infraestrutura | **21.1%** |
| **SQL / Modelagem de Dados** — SQL, modelagem e análise de bancos relacionais. | Dados & Mensageria | **21.1%** |
| **Ansible** — Automação e configuração de infraestrutura. | Automação & Plataforma | **18.4%** |
| **DNS** — Resolução de nomes, conectividade e troubleshooting DNS. | Cloud & Infraestrutura | **18.4%** |
| **EKS** — Amazon Elastic Kubernetes Service. | Cloud & Infraestrutura | **18.4%** |
| **Hands-on / Autonomia** — Atuação prática, autonomia e responsabilidade técnica. | Outros | **18.4%** |
| **Helm** — Gerenciamento de releases e pacotes Kubernetes. | Container & Orquestração | **18.4%** |
| **Logs / Logging** — Coleta, centralização e análise de logs. | Observabilidade e Telemetria | **18.4%** |
| **Performance / Escalabilidade / Tuning** — Performance, escalabilidade, dimensionamento e tuning. | Resiliência e Operação | **18.4%** |
| **RDS** — Amazon RDS e bancos gerenciados. | Cloud & Infraestrutura | **18.4%** |
| **Resiliência / Confiabilidade** — Desenho e operação de sistemas confiáveis e resilientes. | Resiliência e Operação | **18.4%** |
| **Formação Superior** — Formação superior em tecnologia/engenharia. | Outros | **15.8%** |
| **GKE** — Google Kubernetes Engine. | Cloud & Infraestrutura | **15.8%** |
| **Go / Golang** — Programação para automação e ferramentas de plataforma. | Automação & Plataforma | **15.8%** |
| **HPA / Autoscaling** — Escalabilidade automática e gestão de recursos de workloads. | Container & Orquestração | **15.8%** |
| **Métricas / KPIs** — Métricas, KPIs e séries temporais. | Observabilidade e Telemetria | **15.8%** |
| **New Relic** — Observabilidade e APM. | Observabilidade e Telemetria | **15.8%** |
| **PostgreSQL** — PostgreSQL, tuning, conexões, pooling, réplicas e diagnóstico. | Dados & Mensageria | **15.8%** |
| **VPC** — Redes virtuais, segmentação e conectividade AWS. | Cloud & Infraestrutura | **15.8%** |
| **Agile / Scrum / Kanban** — Métodos ágeis e trabalho em squads. | Outros | **13.2%** |
| **Alertas / Alerting** — Detecção e notificação de condições operacionais. | Observabilidade e Telemetria | **13.2%** |
| **Alta Disponibilidade** — Operação e arquitetura de alta disponibilidade. | Resiliência e Operação | **13.2%** |
| **EC2** — Amazon EC2 e infraestrutura de computação. | Cloud & Infraestrutura | **13.2%** |
| **ECR** — Amazon Elastic Container Registry. | Cloud & Infraestrutura | **13.2%** |
| **Mensageria / EDA / Filas** — Mensageria, EDA e processamento assíncrono. | Dados & Mensageria | **13.2%** |
| **OpenTelemetry** — Telemetria distribuída e instrumentação. | Observabilidade e Telemetria | **13.2%** |
| **S3** — Amazon S3 para armazenamento de objetos. | Cloud & Infraestrutura | **13.2%** |
| **TLS / SSL / mTLS** — Criptografia, certificados e comunicação segura. | Segurança & Compliance | **13.2%** |
| **Arquitetura de Software** — Arquitetura, design técnico, padrões e sistemas distribuídos. | Desenvolvimento & Integrações | **10.5%** |
| **Azure DevOps / Pipelines** — Pipelines, repos e boards Azure DevOps. | CI/CD & GitOps | **10.5%** |
| **CloudWatch** — Monitoramento e observabilidade nativa AWS. | Observabilidade e Telemetria | **10.5%** |
| **ConfigMaps / Secrets Kubernetes** — Configuração e gerenciamento de segredos em workloads Kubernetes. | Container & Orquestração | **10.5%** |
| **ECS / Fargate** — Amazon ECS e execução de containers com Fargate. | Cloud & Infraestrutura | **10.5%** |
| **GitLab CI/CD** — Pipelines GitLab. | CI/CD & GitOps | **10.5%** |
| **Java** — Linguagem Java. | Desenvolvimento & Integrações | **10.5%** |
| **Liderança Técnica** — Liderança técnica, influência e decisões arquiteturais. | Outros | **10.5%** |
| **Microserviços** — Arquiteturas baseadas em microserviços. | Container & Orquestração | **10.5%** |
| **RCA** — Análise de causa raiz. | Resiliência e Operação | **10.5%** |
| **SLI / SLO / SLA** — Indicadores, objetivos de nível de serviço e error budgets. | Resiliência e Operação | **10.5%** |
| **Tracing** — Tracing e diagnóstico de sistemas distribuídos. | Observabilidade e Telemetria | **10.5%** |
| **Zabbix** — Monitoramento de infraestrutura e aplicações. | Observabilidade e Telemetria | **10.5%** |
| **APIs REST** — APIs REST e integrações. | Desenvolvimento & Integrações | **7.9%** |
| **Certificações Cloud** — Certificações de cloud e segurança. | Outros | **7.9%** |
| **CloudFormation** — Infrastructure as Code nativo AWS. | Automação & Plataforma | **7.9%** |
| **Compliance** — Requisitos regulatórios, auditoria e compliance. | Segurança & Compliance | **7.9%** |
| **Documentação Técnica** — Documentação técnica e disseminação de conhecimento. | Outros | **7.9%** |
| **Dynatrace** — Observabilidade e APM. | Observabilidade e Telemetria | **7.9%** |
| **FinOps** — Gestão e otimização de custos de cloud. | Cloud & Infraestrutura | **7.9%** |
| **Firewall** — Controle de tráfego e proteção de redes. | Segurança & Compliance | **7.9%** |
| **Gestão de Pessoas** — Gestão e desenvolvimento de pessoas. | Outros | **7.9%** |
| **GitOps** — Operação declarativa e entrega baseada em Git. | CI/CD & GitOps | **7.9%** |
| **IA / AI** — Uso aplicado de inteligência artificial no trabalho técnico. | Outros | **7.9%** |
| **Ingress** — Entrada de tráfego e exposição de serviços Kubernetes. | Container & Orquestração | **7.9%** |
| **Jenkins** — Automação de pipelines CI/CD. | CI/CD & GitOps | **7.9%** |
| **Loki** — Logs e séries temporais no ecossistema Grafana. | Observabilidade e Telemetria | **7.9%** |
| **Multi-Cloud** — Operação e trade-offs entre múltiplos provedores cloud. | Cloud & Infraestrutura | **7.9%** |
| **MySQL** — Banco relacional MySQL. | Dados & Mensageria | **7.9%** |
| **NoSQL** — Bancos não relacionais e operação de NoSQL. | Dados & Mensageria | **7.9%** |
| **Secrets Manager** — Gestão de segredos. | Segurança & Compliance | **7.9%** |
| **Sustentação / Operação** — Operação, sustentação e manutenção de ambientes. | Resiliência e Operação | **7.9%** |
| **AlwaysOn / Multi-AZ / Read Replica** — Alta disponibilidade e replicação de bancos. | Dados & Mensageria | **5.3%** |
| **API Gateway / Kong** — Gateway e governança de APIs. | Desenvolvimento & Integrações | **5.3%** |
| **APNs** — Apple Push Notification Service. | Desenvolvimento & Integrações | **5.3%** |
| **Chef / Chef Automate** — Gerenciamento de configuração e automação. | Automação & Plataforma | **5.3%** |
| **Cloud SQL** — Banco gerenciado Google Cloud. | Cloud & Infraestrutura | **5.3%** |
| **Cloudflare** — Edge, DNS e proteção de tráfego. | Cloud & Infraestrutura | **5.3%** |
| **CloudTrail** — Auditoria e rastreabilidade AWS. | Segurança & Compliance | **5.3%** |
| **Inglês** — Proficiência em inglês. | Outros | **5.3%** |
| **ITSM** — Processos e ferramentas de IT Service Management. | Resiliência e Operação | **5.3%** |
| **Kafka** — Apache Kafka e sistemas orientados a eventos. | Dados & Mensageria | **5.3%** |
| **Kotlin** — Linguagem Kotlin. | Desenvolvimento & Integrações | **5.3%** |
| **Least Privilege / Access Governance** — Princípio do menor privilégio e governança de acessos. | Segurança & Compliance | **5.3%** |
| **MongoDB** — Banco NoSQL MongoDB. | Dados & Mensageria | **5.3%** |
| **Nginx** — Reverse proxy/web server e entrada de tráfego. | Cloud & Infraestrutura | **5.3%** |
| **OpenShift** — Plataforma de containers/Kubernetes OpenShift. | Container & Orquestração | **5.3%** |
| **Puppet** — Gerenciamento de configuração e automação. | Automação & Plataforma | **5.3%** |
| **RabbitMQ** — RabbitMQ e mensageria assíncrona. | Dados & Mensageria | **5.3%** |
| **RBAC Kubernetes** — Controle de acesso baseado em papéis e permissões de workloads/usuários. | Segurança & Compliance | **5.3%** |
| **Redis** — Banco/cache Redis. | Dados & Mensageria | **5.3%** |
| **Testes Automatizados** — Testes automatizados integrados ao ciclo de entrega. | CI/CD & GitOps | **5.3%** |
| **TypeScript** — Linguagem TypeScript. | Desenvolvimento & Integrações | **5.3%** |
| **VPN** — Conectividade privada e VPN. | Cloud & Infraestrutura | **5.3%** |
| **Webhooks** — Integrações orientadas a eventos por webhooks. | Desenvolvimento & Integrações | **5.3%** |
| **Windows** — Conhecimentos de sistemas Windows. | Resiliência e Operação | **5.3%** |
| **.NET** — Ecossistema .NET. | Desenvolvimento & Integrações | **2.6%** |
| **Admission Controllers** — Controles de admissão no Kubernetes. | Segurança & Compliance | **2.6%** |
| **AKS** — Azure Kubernetes Service. | Cloud & Infraestrutura | **2.6%** |
| **Amazon MQ** — Amazon MQ. | Dados & Mensageria | **2.6%** |
| **Apache NiFi** — Automação/integração de fluxos de dados. | Automação & Plataforma | **2.6%** |
| **API Contract Testing** — Validação automatizada de contratos de API em pipeline. | CI/CD & GitOps | **2.6%** |
| **AWS Config** — Avaliação e governança de configuração AWS. | Segurança & Compliance | **2.6%** |
| **AWS Organizations** — Governança multi-account AWS. | Segurança & Compliance | **2.6%** |
| **Azure CLI** — Automação e administração Azure via CLI. | Automação & Plataforma | **2.6%** |
| **Azure Container Apps** — Containers gerenciados no Azure. | Cloud & Infraestrutura | **2.6%** |
| **Azure Database for PostgreSQL** — PostgreSQL gerenciado Azure. | Cloud & Infraestrutura | **2.6%** |
| **Azure Functions** — Computação serverless Azure. | Cloud & Infraestrutura | **2.6%** |
| **Bitbucket** — Repositórios e integração com pipelines. | CI/CD & GitOps | **2.6%** |
| **Blob Storage** — Armazenamento de objetos Azure. | Cloud & Infraestrutura | **2.6%** |
| **Canary / Blue-Green** — Estratégias de deployment progressivo. | CI/CD & GitOps | **2.6%** |
| **Change Management / GMUD** — Governança e controle de mudanças. | Resiliência e Operação | **2.6%** |
| **Clientes Enterprise** — Atuação com clientes enterprise/estratégicos. | Outros | **2.6%** |
| **Cloud Logging** — Logging gerenciado em cloud. | Observabilidade e Telemetria | **2.6%** |
| **Cloud Storage** — Armazenamento de objetos Google Cloud. | Cloud & Infraestrutura | **2.6%** |
| **CloudFront** — CDN e edge AWS. | Cloud & Infraestrutura | **2.6%** |
| **CNAPP / CSPM** — Postura de segurança cloud-native. | Segurança & Compliance | **2.6%** |
| **Compute Engine** — Computação virtual Google Cloud. | Cloud & Infraestrutura | **2.6%** |
| **Conventional Commits** — Padronização de commits. | CI/CD & GitOps | **2.6%** |
| **DDoS / Shield** — Proteção contra ataques de negação de serviço. | Segurança & Compliance | **2.6%** |
| **DynamoDB** — Amazon DynamoDB. | Dados & Mensageria | **2.6%** |
| **Elastic** — Observabilidade e análise de logs. | Observabilidade e Telemetria | **2.6%** |
| **ExpressRoute** — Conectividade privada Azure. | Cloud & Infraestrutura | **2.6%** |
| **Fintech / PCI-DSS** — Experiência no contexto financeiro/fintech. | Outros | **2.6%** |
| **Flux** — GitOps e entrega contínua. | CI/CD & GitOps | **2.6%** |
| **Gradle** — Build automation Java. | Desenvolvimento & Integrações | **2.6%** |
| **Graylog** — Centralização e análise de logs. | Observabilidade e Telemetria | **2.6%** |
| **GuardDuty** — Detecção de ameaças AWS. | Segurança & Compliance | **2.6%** |
| **IAM Access Analyzer** — Análise de acesso e políticas IAM. | Segurança & Compliance | **2.6%** |
| **IAM Identity Center** — Identidade federada e acesso centralizado. | Segurança & Compliance | **2.6%** |
| **Image Scanning** — Análise de vulnerabilidades de imagens. | Segurança & Compliance | **2.6%** |
| **Inspector** — Avaliação de vulnerabilidades AWS. | Segurança & Compliance | **2.6%** |
| **Instana** — Observabilidade e APM. | Observabilidade e Telemetria | **2.6%** |
| **IRSA / Pod Identity** — Identidade de workloads Kubernetes e acesso a recursos cloud. | Segurança & Compliance | **2.6%** |
| **ITIL** — Práticas de IT Service Management. | Resiliência e Operação | **2.6%** |
| **JavaScript** — JavaScript. | Desenvolvimento & Integrações | **2.6%** |
| **Key Vault** — Gestão de chaves/segredos Azure. | Segurança & Compliance | **2.6%** |
| **Keycloak** — Autenticação e gestão de identidade. | Segurança & Compliance | **2.6%** |
| **KMS** — Gestão de chaves criptográficas AWS. | Segurança & Compliance | **2.6%** |
| **Kustomize** — Customização declarativa de manifests Kubernetes. | Container & Orquestração | **2.6%** |
| **Kyverno** — Policy engine para Kubernetes. | Segurança & Compliance | **2.6%** |
| **Lambda** — AWS Lambda e computação serverless. | Cloud & Infraestrutura | **2.6%** |
| **Landing Zones / Cloud Governance** — Governança e padronização de ambientes cloud. | Cloud & Infraestrutura | **2.6%** |
| **Macie** — Descoberta/proteção de dados sensíveis AWS. | Segurança & Compliance | **2.6%** |
| **NetworkPolicy** — Isolamento e controle de tráfego entre workloads. | Segurança & Compliance | **2.6%** |
| **Node.js** — Runtime Node.js. | Desenvolvimento & Integrações | **2.6%** |
| **OAuth / JWT** — Padrões de autenticação e autorização. | Segurança & Compliance | **2.6%** |
| **OPA / Gatekeeper** — Policy enforcement e admission control. | Segurança & Compliance | **2.6%** |
| **OpenTofu** — Infrastructure as Code compatível com o ecossistema Terraform. | Automação & Plataforma | **2.6%** |
| **Permission Boundaries** — Limitação de permissões máximas IAM. | Segurança & Compliance | **2.6%** |
| **PgBouncer** — Connection pooling PostgreSQL. | Dados & Mensageria | **2.6%** |
| **Ping Identity** — Gestão de identidade e autenticação. | Segurança & Compliance | **2.6%** |
| **Policy as Code / Detection as Code** — Políticas e detecções como código. | Segurança & Compliance | **2.6%** |
| **PowerShell** — Scripting e automação em ambientes Microsoft. | Automação & Plataforma | **2.6%** |
| **PrivateLink** — Conectividade privada entre serviços AWS. | Cloud & Infraestrutura | **2.6%** |
| **Pulumi** — Infrastructure as Code. | Automação & Plataforma | **2.6%** |
| **Route 53** — DNS gerenciado AWS. | Cloud & Infraestrutura | **2.6%** |
| **Ruby** — Linguagem Ruby. | Desenvolvimento & Integrações | **2.6%** |
| **Runtime Security** — Segurança de workloads em runtime. | Segurança & Compliance | **2.6%** |
| **SCP** — Service Control Policies AWS. | Segurança & Compliance | **2.6%** |
| **Security Hub** — Centralização de findings de segurança AWS. | Segurança & Compliance | **2.6%** |
| **Service Mesh** — Camada de comunicação, segurança e observabilidade entre serviços. | Container & Orquestração | **2.6%** |
| **Spring / Spring Boot** — Framework Java Spring/Spring Boot. | Desenvolvimento & Integrações | **2.6%** |
| **SQS** — Amazon Simple Queue Service. | Dados & Mensageria | **2.6%** |
| **Threat Modeling** — Modelagem de ameaças. | Segurança & Compliance | **2.6%** |
| **Transit Gateway** — Interconexão de redes/VPCs AWS. | Cloud & Infraestrutura | **2.6%** |
| **VNet** — Redes virtuais Azure. | Cloud & Infraestrutura | **2.6%** |
| **VPA** — Vertical Pod Autoscaler. | Container & Orquestração | **2.6%** |
| **WAF** — Web Application Firewall. | Segurança & Compliance | **2.6%** |

## Temáticas

| Temática | Escopo |
|---|---|
| Container & Orquestração | Kubernetes, Docker, containers, Helm, Ingress, OpenShift, autoscaling, microserviços e service mesh. |
| Automação & Plataforma | Terraform, Ansible, CloudFormation, scripting, Python, Go, PowerShell e automação operacional. |
| CI/CD & GitOps | Git, GitHub Actions, GitLab CI, Jenkins, Azure DevOps, Argo CD, Flux, GitOps e estratégias de deployment. |
| Observabilidade e Telemetria | Grafana, Prometheus, Datadog, New Relic, Dynatrace, OpenTelemetry, logs, métricas, alertas e tracing. |
| Resiliência e Operação | SRE, troubleshooting, incidentes, RCA, SLOs, disponibilidade, performance, produção e ITSM. |
| Cloud & Infraestrutura | AWS, GCP, Azure, redes, compute, storage, load balancers, DNS e governança cloud. |
| Segurança & Compliance | IAM, RBAC, secrets, hardening, DevSecOps, segurança Kubernetes/cloud, políticas e compliance. |
| Dados & Mensageria | PostgreSQL, MySQL, MongoDB, Redis, Kafka, RabbitMQ, SQL/NoSQL, pooling e replicação. |
| Desenvolvimento & Integrações | Java, Kotlin, APIs REST, webhooks, API Gateway, arquitetura, Spring e integrações. |
| Outros | Formação, certificações, liderança, gestão, comunicação, métodos ágeis, IA e contexto enterprise. |

## Como interpretar

- `60,5%` significa que o requisito apareceu em **23 dos 38 blocos** analisados.
- O percentual **não representa importância**, senioridade ou obrigatoriedade.
- Requisitos desejáveis/diferenciais são contabilizados quando aparecem no bloco da vaga, sem atribuir peso adicional.
- Tecnologias específicas de uma plataforma não são automaticamente somadas à plataforma pai. Por exemplo, `EKS` é contabilizado separadamente de `AWS`; isso evita inflar artificialmente os percentuais.
- Conceitos amplos, como `Observabilidade`, `Automação` e `CI/CD`, são mantidos porque aparecem explicitamente como requisitos nas vagas e são úteis para a análise de competências.

## Uso recomendado

Esta tabela pode servir como base para três artefatos derivados:

1. **Mapa de mercado** — quais competências aparecem com maior frequência nas vagas analisadas.
2. **Plano de estudos** — cruzar cada requisito com conhecimento atual, prioridade e prática no laboratório local.
3. **Post do LinkedIn** — utilizar os requisitos de maior representatividade para construir os gráficos e destacar os principais padrões encontrados.

## Fonte

Os dados foram extraídos exclusivamente do arquivo original `requisitos_SRE.txt`. Não foram incorporados requisitos de mercado externo que não aparecem na fonte.
