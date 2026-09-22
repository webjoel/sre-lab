# Requisitos das vagas de SRE — listagem completa

Extração de **38 descrições de vaga** para posições de SRE sênior e liderança de times SRE
(Brasil, 2026). Cada requisito é contado **uma vez por vaga**, independente de quantas vezes aparece
no texto. A representatividade é a fração de vagas que cita o item.

Itens aparecem no nível mais granular possível: `Amazon EKS`, `Google GKE` e `Azure AKS` são linhas
separadas, e não uma linha "Kubernetes gerenciado". Conceitos (por exemplo, "Observabilidade") e
ferramentas (por exemplo, "Prometheus") também são linhas distintas, porque uma vaga pode pedir o
conceito sem citar ferramenta.

**Como ler:** frequência alta indica o que é exigido em quase toda vaga; frequência baixa **não**
indica irrelevância — vários itens de baixa frequência (SLO, error budget, canary) são justamente
os mais cobrados em entrevista, porque diferenciam nível sênior.

Total: **213 requisitos distintos** identificados.

| # | Requisito | Temática | Representatividade |
|---:|---|---|---:|
| 1 | Observabilidade (conceito) | Observabilidade & Telemetria | 79% |
| 2 | Infrastructure as Code (conceito) | IaC & Automação | 63% |
| 3 | AWS | Cloud & Infraestrutura | 61% |
| 4 | Automação de processos | IaC & Automação | 58% |
| 5 | CI/CD (conceito) | CI/CD & GitOps | 58% |
| 6 | Terraform | IaC & Automação | 55% |
| 7 | Kubernetes | Container & Orquestração | 53% |
| 8 | Containers (conceito) | Container & Orquestração | 45% |
| 9 | Grafana | Observabilidade & Telemetria | 45% |
| 10 | Monitoramento | Observabilidade & Telemetria | 39% |
| 11 | Python | Linguagens & Desenvolvimento | 39% |
| 12 | Google Cloud (GCP) | Cloud & Infraestrutura | 37% |
| 13 | Pipelines | CI/CD & GitOps | 37% |
| 14 | Redes (fundamentos) | Redes | 37% |
| 15 | Troubleshooting | Confiabilidade & Operação | 34% |
| 16 | Arquitetura e design de sistemas | Linguagens & Desenvolvimento | 32% |
| 17 | Linux | Cloud & Infraestrutura | 32% |
| 18 | Microsoft Azure | Cloud & Infraestrutura | 32% |
| 19 | Prometheus | Observabilidade & Telemetria | 32% |
| 20 | Experiência em ambientes de produção | Confiabilidade & Operação | 29% |
| 21 | Comunicação / stakeholders | Processo & Gestão | 26% |
| 22 | Datadog | Observabilidade & Telemetria | 26% |
| 23 | Docker | Container & Orquestração | 26% |
| 24 | GitHub | CI/CD & GitOps | 26% |
| 25 | GitHub Actions | CI/CD & GitOps | 26% |
| 26 | Práticas de SRE | Confiabilidade & Operação | 26% |
| 27 | Argo CD | CI/CD & GitOps | 24% |
| 28 | Bash / Shell Script | Linguagens & Desenvolvimento | 24% |
| 29 | Gestão de incidentes | Confiabilidade & Operação | 24% |
| 30 | IAM / gestão de acessos | Segurança & Compliance | 24% |
| 31 | Load Balancer (ALB/NLB) | Redes | 21% |
| 32 | Amazon EKS | Container & Orquestração | 18% |
| 33 | Amazon RDS | Cloud & Infraestrutura | 18% |
| 34 | Ansible | IaC & Automação | 18% |
| 35 | APIs REST | Linguagens & Desenvolvimento | 18% |
| 36 | DNS | Redes | 18% |
| 37 | Helm | Container & Orquestração | 18% |
| 38 | Logs / logging | Observabilidade & Telemetria | 18% |
| 39 | Performance / tuning | Confiabilidade & Operação | 18% |
| 40 | VPC / VNet | Redes | 18% |
| 41 | Autonomia / proatividade | Processo & Gestão | 16% |
| 42 | Git | CI/CD & GitOps | 16% |
| 43 | Go / Golang | Linguagens & Desenvolvimento | 16% |
| 44 | Google GKE | Container & Orquestração | 16% |
| 45 | Hands-on / atuação prática | Processo & Gestão | 16% |
| 46 | HPA / VPA (autoscaling) | Container & Orquestração | 16% |
| 47 | New Relic | Observabilidade & Telemetria | 16% |
| 48 | PostgreSQL | Dados & Mensageria | 16% |
| 49 | SQL (linguagem) | Dados & Mensageria | 16% |
| 50 | Alertas | Observabilidade & Telemetria | 13% |
| 51 | Amazon EC2 | Cloud & Infraestrutura | 13% |
| 52 | Amazon S3 | Cloud & Infraestrutura | 13% |
| 53 | Code review / pull request | CI/CD & GitOps | 13% |
| 54 | Firewall / Security Group / NACL | Redes | 13% |
| 55 | Mensageria / EDA | Dados & Mensageria | 13% |
| 56 | Multi-AZ / alta disponibilidade | Cloud & Infraestrutura | 13% |
| 57 | Métricas | Observabilidade & Telemetria | 13% |
| 58 | OpenTelemetry | Observabilidade & Telemetria | 13% |
| 59 | Sistemas distribuídos | Confiabilidade & Operação | 13% |
| 60 | SSL / TLS | Segurança & Compliance | 13% |
| 61 | Trabalho em equipe / colaboração | Processo & Gestão | 13% |
| 62 | Amazon ECS | Container & Orquestração | 11% |
| 63 | Azure DevOps / Pipelines | CI/CD & GitOps | 11% |
| 64 | FinOps / custos | Confiabilidade & Operação | 11% |
| 65 | GitLab CI | CI/CD & GitOps | 11% |
| 66 | Java | Linguagens & Desenvolvimento | 11% |
| 67 | Liderança técnica | Processo & Gestão | 11% |
| 68 | Microsserviços | Confiabilidade & Operação | 11% |
| 69 | Root Cause Analysis (RCA) | Confiabilidade & Operação | 11% |
| 70 | Scrum | Processo & Gestão | 11% |
| 71 | Secrets management | Segurança & Compliance | 11% |
| 72 | SLO | Confiabilidade & Operação | 11% |
| 73 | Tracing distribuído | Observabilidade & Telemetria | 11% |
| 74 | Versionamento / branching | CI/CD & GitOps | 11% |
| 75 | VPN | Redes | 11% |
| 76 | Zabbix | Observabilidade & Telemetria | 11% |
| 77 | AWS Fargate | Cloud & Infraestrutura | 8% |
| 78 | Certificações | Idiomas & Formação | 8% |
| 79 | CloudFormation | IaC & Automação | 8% |
| 80 | CloudWatch | Observabilidade & Telemetria | 8% |
| 81 | Dynatrace | Observabilidade & Telemetria | 8% |
| 82 | GitOps (conceito) | CI/CD & GitOps | 8% |
| 83 | Hardening | Segurança & Compliance | 8% |
| 84 | IA aplicada / GenAI | IA | 8% |
| 85 | Ingress | Container & Orquestração | 8% |
| 86 | JavaScript | Linguagens & Desenvolvimento | 8% |
| 87 | Jenkins | CI/CD & GitOps | 8% |
| 88 | Kanban | Processo & Gestão | 8% |
| 89 | Loki | Observabilidade & Telemetria | 8% |
| 90 | MySQL | Dados & Mensageria | 8% |
| 91 | NoSQL (conceito) | Dados & Mensageria | 8% |
| 92 | OIDC / OAuth / JWT | Segurança & Compliance | 8% |
| 93 | Runbooks / documentação técnica | Confiabilidade & Operação | 8% |
| 94 | SLI | Confiabilidade & Operação | 8% |
| 95 | Amazon SQS / SNS / AmazonMQ | Dados & Mensageria | 5% |
| 96 | Apache Kafka | Dados & Mensageria | 5% |
| 97 | Apache NiFi | Dados & Mensageria | 5% |
| 98 | API Gateway / Kong | Linguagens & Desenvolvimento | 5% |
| 99 | APM | Observabilidade & Telemetria | 5% |
| 100 | APNs (push notifications) | Linguagens & Desenvolvimento | 5% |
| 101 | AWS Landing Zone | Cloud & Infraestrutura | 5% |
| 102 | Chef | IaC & Automação | 5% |
| 103 | Cloudflare | Cloud & Infraestrutura | 5% |
| 104 | CloudTrail / trilha de auditoria | Segurança & Compliance | 5% |
| 105 | Compliance / auditoria | Segurança & Compliance | 5% |
| 106 | Contratos de API | Linguagens & Desenvolvimento | 5% |
| 107 | Dashboards | Observabilidade & Telemetria | 5% |
| 108 | Escalabilidade | Confiabilidade & Operação | 5% |
| 109 | GCP Cloud SQL | Cloud & Infraestrutura | 5% |
| 110 | Gestão de pessoas / PDI | Processo & Gestão | 5% |
| 111 | Inglês | Idiomas & Formação | 5% |
| 112 | ITSM | Processo & Gestão | 5% |
| 113 | Kotlin | Linguagens & Desenvolvimento | 5% |
| 114 | MongoDB | Dados & Mensageria | 5% |
| 115 | Nginx | Redes | 5% |
| 116 | OpenShift | Container & Orquestração | 5% |
| 117 | Plantão / on-call | Confiabilidade & Operação | 5% |
| 118 | Postmortem | Confiabilidade & Operação | 5% |
| 119 | Puppet | IaC & Automação | 5% |
| 120 | RabbitMQ | Dados & Mensageria | 5% |
| 121 | RBAC (Kubernetes) | Container & Orquestração | 5% |
| 122 | Redis | Dados & Mensageria | 5% |
| 123 | Resiliência | Confiabilidade & Operação | 5% |
| 124 | Réplicas de leitura | Dados & Mensageria | 5% |
| 125 | TCP/IP | Redes | 5% |
| 126 | TypeScript | Linguagens & Desenvolvimento | 5% |
| 127 | Webhooks | Linguagens & Desenvolvimento | 5% |
| 128 | Windows Server | Cloud & Infraestrutura | 5% |
| 129 | .NET | Linguagens & Desenvolvimento | 3% |
| 130 | Admission controller | Segurança & Compliance | 3% |
| 131 | Alta disponibilidade (SQL Server AlwaysOn) | Dados & Mensageria | 3% |
| 132 | Amazon CloudFront | Cloud & Infraestrutura | 3% |
| 133 | Amazon DynamoDB | Cloud & Infraestrutura | 3% |
| 134 | Amazon EventBridge | Cloud & Infraestrutura | 3% |
| 135 | Application Insights | Observabilidade & Telemetria | 3% |
| 136 | AWS GuardDuty / Security Hub / Inspector | Segurança & Compliance | 3% |
| 137 | AWS Lambda | Cloud & Infraestrutura | 3% |
| 138 | AWS Organizations | Cloud & Infraestrutura | 3% |
| 139 | AWS PrivateLink | Cloud & Infraestrutura | 3% |
| 140 | AWS Transit Gateway | Cloud & Infraestrutura | 3% |
| 141 | Azure AKS | Container & Orquestração | 3% |
| 142 | Azure Blob Storage | Cloud & Infraestrutura | 3% |
| 143 | Azure CLI | Cloud & Infraestrutura | 3% |
| 144 | Azure Container Apps | Cloud & Infraestrutura | 3% |
| 145 | Azure Database | Cloud & Infraestrutura | 3% |
| 146 | Azure ExpressRoute | Cloud & Infraestrutura | 3% |
| 147 | Azure Functions | Cloud & Infraestrutura | 3% |
| 148 | Bitbucket | CI/CD & GitOps | 3% |
| 149 | Blue/Green | CI/CD & GitOps | 3% |
| 150 | CNAPP / CSPM | Segurança & Compliance | 3% |
| 151 | Conventional Commits | CI/CD & GitOps | 3% |
| 152 | Cultura DevOps | Processo & Gestão | 3% |
| 153 | Deploy canário | CI/CD & GitOps | 3% |
| 154 | Detection as code | Segurança & Compliance | 3% |
| 155 | DevSecOps | Segurança & Compliance | 3% |
| 156 | Dockerfile | Container & Orquestração | 3% |
| 157 | Elastic / ELK | Observabilidade & Telemetria | 3% |
| 158 | Ensino superior | Idiomas & Formação | 3% |
| 159 | Error budget | Confiabilidade & Operação | 3% |
| 160 | Flux | CI/CD & GitOps | 3% |
| 161 | GCP Cloud Monitoring/Logging | Observabilidade & Telemetria | 3% |
| 162 | GCP Cloud Storage | Cloud & Infraestrutura | 3% |
| 163 | GCP Compute Engine | Cloud & Infraestrutura | 3% |
| 164 | GDPR / LGPD | Segurança & Compliance | 3% |
| 165 | Gestão de vulnerabilidades | Segurança & Compliance | 3% |
| 166 | GMUD / change management | Processo & Gestão | 3% |
| 167 | Gradle | CI/CD & GitOps | 3% |
| 168 | Graylog | Observabilidade & Telemetria | 3% |
| 169 | HashiCorp Vault | Segurança & Compliance | 3% |
| 170 | HIPAA | Segurança & Compliance | 3% |
| 171 | HTTP / HTTPS | Redes | 3% |
| 172 | Image scanning | Segurança & Compliance | 3% |
| 173 | Instana | Observabilidade & Telemetria | 3% |
| 174 | IRSA / identidade de pod | Container & Orquestração | 3% |
| 175 | ITIL | Processo & Gestão | 3% |
| 176 | Keycloak | Segurança & Compliance | 3% |
| 177 | KMS / criptografia | Segurança & Compliance | 3% |
| 178 | KPIs | Observabilidade & Telemetria | 3% |
| 179 | Kustomize | Container & Orquestração | 3% |
| 180 | Least privilege / JIT | Segurança & Compliance | 3% |
| 181 | Manifests YAML | Container & Orquestração | 3% |
| 182 | Metodologias ágeis | Processo & Gestão | 3% |
| 183 | mTLS | Segurança & Compliance | 3% |
| 184 | MTTR / MTTD | Confiabilidade & Operação | 3% |
| 185 | Multi-cloud | Cloud & Infraestrutura | 3% |
| 186 | NetworkPolicy / isolamento de workloads | Segurança & Compliance | 3% |
| 187 | Node.js | Linguagens & Desenvolvimento | 3% |
| 188 | OpenTofu | IaC & Automação | 3% |
| 189 | PCI-DSS | Segurança & Compliance | 3% |
| 190 | Permission boundaries | Segurança & Compliance | 3% |
| 191 | PgBouncer / pool de conexões | Dados & Mensageria | 3% |
| 192 | Platform engineering | Processo & Gestão | 3% |
| 193 | Policy as code (OPA / Kyverno) | Segurança & Compliance | 3% |
| 194 | Português | Idiomas & Formação | 3% |
| 195 | PowerShell | Linguagens & Desenvolvimento | 3% |
| 196 | Pulumi | IaC & Automação | 3% |
| 197 | Red Hat | Cloud & Infraestrutura | 3% |
| 198 | Rollback | CI/CD & GitOps | 3% |
| 199 | Route 53 / DNS gerenciado | Redes | 3% |
| 200 | Ruby | Linguagens & Desenvolvimento | 3% |
| 201 | Runtime security | Segurança & Compliance | 3% |
| 202 | Service mesh / Istio | Redes | 3% |
| 203 | Setor financeiro / fintech | Processo & Gestão | 3% |
| 204 | SLA | Confiabilidade & Operação | 3% |
| 205 | SOC 2 | Segurança & Compliance | 3% |
| 206 | Spring / Spring Boot | Linguagens & Desenvolvimento | 3% |
| 207 | SQL Server | Dados & Mensageria | 3% |
| 208 | Testes automatizados | CI/CD & GitOps | 3% |
| 209 | Threat modeling | Segurança & Compliance | 3% |
| 210 | Toil / redução de trabalho manual | Confiabilidade & Operação | 3% |
| 211 | Ubuntu | Cloud & Infraestrutura | 3% |
| 212 | VLAN | Redes | 3% |
| 213 | WAF / DDoS / Shield | Segurança & Compliance | 3% |

## Distribuição por temática

Soma das menções de todos os itens de cada temática, como indicador de peso relativo.

| Temática | Itens distintos | Menções somadas |
|---|---:|---:|
| Observabilidade & Telemetria | 23 | 139 |
| Cloud & Infraestrutura | 31 | 112 |
| CI/CD & GitOps | 20 | 102 |
| Container & Orquestração | 16 | 89 |
| Confiabilidade & Operação | 20 | 89 |
| IaC & Automação | 9 | 83 |
| Linguagens & Desenvolvimento | 18 | 73 |
| Redes | 12 | 53 |
| Segurança & Compliance | 29 | 50 |
| Processo & Gestão | 15 | 48 |
| Dados & Mensageria | 15 | 40 |
| Idiomas & Formação | 4 | 7 |
| IA | 1 | 3 |

## Metodologia e limites

- Fonte: 38 descrições de vaga coletadas no LinkedIn.
- Contagem por correspondência de termos e sinônimos (`K8s` conta como Kubernetes, `Golang` como
  Go, `IaC` como Infrastructure as Code). Cada item é contado uma vez por vaga.
- **Serviços gerenciados não são somados à plataforma-mãe.** Uma vaga que cita apenas "EKS" conta
  para EKS, e não para Kubernetes. Isso mantém a granularidade, mas torna os números de conceitos
  amplos mais conservadores do que em análises que fazem essa soma.
- Termos genéricos ("automação", "documentação", "arquitetura") aparecem muito porque são descritos
  de várias formas nos textos; leia como tema recorrente, não como ferramenta.
- Amostra pequena e de um recorte específico (SRE sênior e liderança, Brasil). Não representa o
  mercado inteiro.
