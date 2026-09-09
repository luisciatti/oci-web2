# Layer: core/global

## Objetivo
Primeira layer com backend remoto de verdade (state guardado no bucket criado pelo `foundation`). Cria o compartment principal onde vive toda a infraestrutura da aplicação.

## Recursos criados
| Recurso | Nome | Propósito |
|---|---|---|
| `oci_identity_compartment` | `cmp-app` | Compartment principal — "pasta lógica" onde moram rede, banco, VMs, etc |

## State
Remoto — backend `s3` apontando para `oci-testhub-tfstate`, key `core/global/sa-saopaulo-1.tfstate`.

```hcl
backend "s3" {
  bucket                      = "oci-testhub-tfstate"
  key                         = "core/global/sa-saopaulo-1.tfstate"
  region                      = "sa-saopaulo-1"
  endpoint                    = "https://<namespace>.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  use_path_style              = true
  skip_s3_checksum            = true
}
```
Esse bloco se repete (só trocando o `key`) em toda layer daqui pra frente.

## Outputs
```hcl
output "app_compartment_id" {
  value = oci_identity_compartment.app.id
}
```
Consumido pela layer `security` (e será consumido por todas as seguintes) via `terraform_remote_state`.

## Decisões e por quês
- **Um compartment só, direto no tenancy**: o exemplo original (EMR OCI Platform) usa múltiplos compartments por propósito (`cmp-network`, `cmp-security`, etc) para separar permissões por equipe. Como este é um projeto pessoal/single-tenant, simplificamos para um único `cmp-app` guarda-chuva.

## Validação feita
- Local: `tofu apply` criou o compartment; confirmado ausência de `terraform.tfstate` local e presença do arquivo no bucket via `oci os object list`.
- CI/CD: `tofu plan` via GitHub Actions (workflow manual `workflow_dispatch`) leu o state remoto e confirmou "No changes" — primeira prova de que o pipeline consegue autenticar e operar sobre a mesma infraestrutura que o ambiente local.

## Bugs/gotchas descobertos aqui
- Erro `AuthorizationHeaderMalformed` / `SignatureDoesNotMatch`: causado por Access Key e Secret Key trocadas de posição ao exportar as variáveis de ambiente localmente. Diagnosticado observando que o valor usado como `Credential` no erro tinha formato de base64 (características de Secret Key), não de Access Key ID.