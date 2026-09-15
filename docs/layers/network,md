# Layer: core/network

## Objetivo
Construir a rede (VCN) que vai hospedar todos os recursos futuros: uma subnet pública (para Load Balancer/Bastion) e uma subnet privada (para Kubernetes, banco de dados), cada uma com sua própria política de saída para a internet.

## Recursos criados
| Recurso | Nome | Propósito |
|---|---|---|
| `oci_core_vcn` | `brazil_vcn` | A rede em si — CIDR `10.0.0.0/16` |
| `oci_core_internet_gateway` | `brazil_ig` | Porta de entrada/saída direta para a subnet pública |
| `oci_core_nat_gateway` | `brazil_nat` | Permite a subnet privada acessar a internet sem ser alcançável de fora |
| `oci_core_service_gateway` | `sgw-network` | Rota direta e gratuita (dentro da rede interna da Oracle) para serviços OCI como Object Storage, sem passar pelo NAT |
| `oci_core_route_table` | `brazil_rt_public` | Rota da subnet pública → Internet Gateway |
| `oci_core_route_table` | `brazil_rt_private` | Rota da subnet privada → NAT Gateway (tráfego geral) + Service Gateway (serviços OCI) |
| `oci_core_security_list` | `brazil_sl_public` | Firewall da subnet pública: libera entrada 80/443 de qualquer lugar, saída total |
| `oci_core_security_list` | `brazil_sl_private` | Firewall da subnet privada: libera entrada só de dentro da própria VCN (`10.0.0.0/16`), saída total |
| `oci_core_subnet` | `brazil_subnet_public` | `10.0.1.0/24` — permite IP público |
| `oci_core_subnet` | `brazil_subnet_private` | `10.0.2.0/24` — `prohibit_public_ip_on_vnic = true`, nenhum recurso aqui pode ter IP público |
| `data.oci_core_services` | `all_oci_services` | Data source usado para referenciar o "pacote" de serviços OCI acessíveis via Service Gateway |

## State
Remoto — key `core/network/sa-saopaulo-1.tfstate`.

## Diagrama de rede
```
                            Internet
                                │
                    ┌───────────┴───────────┐
                    │  Internet Gateway      │
                    └───────────┬───────────┘
                                │
              ┌─────────────────┴─────────────────┐
              │   Subnet Pública (10.0.1.0/24)     │
              │   route → IGW | SL: 80/443 in      │
              └─────────────────────────────────────┘

    VCN 10.0.0.0/16
              ┌─────────────────────────────────────┐
              │   Subnet Privada (10.0.2.0/24)      │
              │   sem IP público                     │
              │   route → NAT Gateway (internet)     │
              │   route → Service Gateway (OCI)      │
              └───────┬───────────────────┬─────────┘
                      │                   │
              ┌───────┴──────┐   ┌────────┴─────────┐
              │ NAT Gateway  │   │ Service Gateway   │
              └───────┬──────┘   └────────┬─────────┘
                      │                   │
                  Internet      Serviços OCI (Object Storage etc.)
```

## Outputs
```hcl
output "vcn_id" { value = oci_core_vcn.brazil_vcn.id }
output "public_subnet_id" { value = oci_core_subnet.brazil_subnet_public.id }
output "private_subnet_id" { value = oci_core_subnet.brazil_subnet_private.id }
output "service_gateway_id" { value = oci_core_service_gateway.main.id }
```
Vão ser consumidos pela layer `environment` (spoke) e futuramente por `database` (subnet do Autonomous DB) e pelo cluster Kubernetes (I-13).

## Decisões e por quês
- **Uma VCN só, sem hub-and-spoke multi-VCN**: o exemplo original (EMR OCI Platform) usa hub-and-spoke com DRG conectando múltiplas VCNs (uma por cliente/tenancy). Para este projeto single-tenant, uma VCN com subnet pública/privada é suficiente e mais simples de raciocinar.
- **Security Lists em vez de (só) NSGs**: Security Lists aplicam regras à subnet inteira — mais simples para o estágio atual. NSGs (regras por recurso específico) ficam para o I-04, quando fizer sentido ter granularidade por grupo de VMs/nodes.
- **Service Gateway adicionado à parte, depois da subnet já existir**: mostra na prática que uma layer pode ser estendida incrementalmente — o Terraform apenas adiciona o recurso novo e atualiza a route table existente, sem tocar no resto.

## Validação feita
- `tofu apply` em duas etapas (bloqueado no meio por limite de serviço, retomado depois) — demonstrou na prática que o Terraform continua de onde parou, sem duplicar recursos já criados com sucesso.
- `tofu output` confirmou os 4 valores preenchidos.

## Bugs/gotchas descobertos aqui
- **`400-LimitExceeded, NAT gateway limit per VCN reached`**: contas OCI no nível "Trial" vêm com o limite de serviço (`nat-gateway-count`) zerado por padrão — trava de segurança da Oracle contra abuso de contas novas, não relacionado a custo. Contas Trial também **não podem solicitar aumento de limite via autoatendimento** (`Your tenancy is not eligible to submit a limit request`) — é necessário fazer upgrade para Pay As You Go (adicionar cartão) primeiro. O upgrade não implica cobrança automática: recursos Always Free continuam grátis, o upgrade só libera a permissão de configurar limites mais altos.
- **Apply parcial**: quando um `resource` falha no meio do `apply`, os recursos já criados com sucesso ficam no state normalmente — rodar `plan`/`apply` de novo só tenta criar o que falta, sem duplicar.
- **`route_rules` múltiplas são recriadas inteiras, não "append"**: ao adicionar uma segunda regra (`route_rules`) numa `oci_core_route_table` já existente, o provider da OCI mostra a primeira regra como removida e recriada (mesmo com valores idênticos), em vez de só adicionar a nova. Comportamento esperado desse provider para blocos repetíveis declarados inline — não é erro, é seguro de aplicar.

## Proteções financeiras criadas neste ponto do projeto
Como o upgrade para Pay As You Go foi necessário aqui, aproveitamos para criar duas camadas de alerta de orçamento (Cost Management → Budgets):
- **Actual Spend**: dispara em 1% de um budget de R$10 — avisa assim que qualquer cobrança real acontecer.
- **Forecast Spend**: dispara em 1% do mesmo budget, baseado na projeção de gasto do mês — avisa antes mesmo da cobrança acontecer, dando tempo de corrigir.