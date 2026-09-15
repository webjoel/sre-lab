# ADR 0001 — Cluster kind com 1 control plane e 1 worker, perfis de carga

- Status: aceita
- Data: 2026-09-10

## Contexto
O laboratório roda em um notebook com Intel Core i7-8565U (4 núcleos / 8 threads) e 16 GiB de RAM,
dividindo recursos com o desktop Ubuntu, navegador e IDE. Sobra algo em torno de 9 a 10 GiB para o lab.
A stack completa (plataforma, observabilidade, LLM) passaria de 20 GiB se ligada ao mesmo tempo.

## Decisão
- kind com 1 control plane + 1 worker por padrão (`worker_count` permite até 3 para exercícios de scheduling).
- Componentes organizados em perfis; só o perfil da fase em estudo fica ligado.
- Tarefas pesadas de CI (builds, scans, DAST) rodam nos runners do GitHub, não na máquina local.
- LLM roda via Ollama no host com modelo pequeno, fora do cluster, para evitar sobrecarga dupla.

## Alternativas consideradas
- **k3d/k3s**: mais leve (cerca de 0,5 GiB a menos), mas o kind é o mesmo usado nos ambientes efêmeros do CI e é mais próximo do Kubernetes upstream.
- **VM na nuvem para tudo**: mais recursos, porém com custo recorrente e sem o aprendizado de otimização de recursos.

## Consequências
- Observabilidade completa e LLM não ficam ligados juntos; o perfil de IA usa observabilidade reduzida.
- Medir consumo (`make status`, `kubectl top`) e ajustar requests/limits vira parte do estudo.
- Em produção, a mesma lógica aparece como capacity planning e rightsizing.
