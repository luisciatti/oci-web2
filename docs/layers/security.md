# Layer: core/security

## Objetivo
Equivalente funcional de um "Secrets Manager": provisiona o Vault (KMS) e uma chave de criptografia, e guarda a senha do banco de dados como secret — nunca em texto puro no código ou em `.tfvars`.

Na OCI, isso é dividido em dois serviços que trabalham juntos (diferente da AWS, onde é um serviço único):
- **KMS (Key Management Service)** — cria e gerencia as chaves de criptografia
- **Vault Secrets** — guarda os segredos em si, criptografados por uma key do KMS

## Recursos criados
| Recurso | Nome | Propósito |
|---|---|---|
| `oci_kms_vault` | `vault-app-main` | O "cofre" — container lógico. Tipo `DEFAULT` (software, grátis) |
| `oci_kms_key` | `key-app-secrets` | A "fechadura" — chave AES-256, `protection_mode = "SOFTWARE"` (grátis; `HSM` seria pago) |
| `random_password` | `db_admin` | Senha aleatória gerada pelo próprio Terraform (20 caracteres, regras compatíveis com Autonomous Database) |
| `oci_vault_secret` | `secret-db-admin-password` | A senha, criptografada com a key acima, guardada dentro do Vault |

## State
Remoto — key `core/security/sa-saopaulo-1.tfstate`.

## Novo padrão introduzido: `terraform_remote_state`
Primeira layer a **ler** dados de outra layer, em vez de só criar recursos isolados:

```hcl
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "oci-testhub-tfstate"
    key    = "core/global/sa-saopaulo-1.tfstate"
    # ... mesmos parâmetros skip_*/use_path_style/skip_s3_checksum
  }
}
```
Uso: `data.terraform_remote_state.global.outputs.app_compartment_id`

Isso implementa o "state isolation por layer": cada layer só enxerga da anterior o que foi explicitamente exposto via `output` — nunca acessa o state alheio diretamente.

## Novo provider: `hashicorp/random`
Não fala com nenhuma nuvem — gera valores aleatórios (senhas, sufixos) determinísticos dentro do próprio state (gera uma vez, mantém o valor nas execuções seguintes, a menos que seja forçado a recriar).

```hcl
required_providers {
  random = {
    source  = "hashicorp/random"
    version = "~> 3.6"
  }
}
```

## Outputs
```hcl
output "vault_id" { value = oci_kms_vault.main.id }
output "vault_management_endpoint" { value = oci_kms_vault.main.management_endpoint }
output "key_id" { value = oci_kms_key.app.id }
output "db_admin_secret_id" { value = oci_vault_secret.db_admin_password.id }
```
**Nunca** expor `random_password.db_admin.result` como output — apareceria em texto puro em qualquer `tofu output`. A prática correta é expor só o **ID do secret**; quem precisar do valor real busca via API/CLI com permissão explícita (`oci secrets secret-bundle get`).

## Decisões e por quês
- **Vault tipo `DEFAULT` (não `VIRTUAL_PRIVATE`)**: Always Free — HSM é pago.
- **`protection_mode = "SOFTWARE"` (não `HSM`)**: mesmo motivo.
- **Senha gerada por `random_password`, nunca digitada manualmente**: elimina risco de senha fraca ou vazamento por estar em `.tfvars`/histórico de shell.

## Validação feita
- `tofu plan` mostrou campos sensíveis (`content`, `result`, `bcrypt_hash`) automaticamente ocultos como `(sensitive value)`.
- `tofu output` após apply mostrou apenas o ID do secret, nunca a senha.
- `oci vault secret list` confirmou o secret `ACTIVE`, sem expor o conteúdo (para ver o valor real seria necessário `secret-bundle get`, endpoint separado, com permissão explícita).

## Bugs/gotchas descobertos aqui
- **`layer/.env` não versionado**: como o arquivo de credenciais locais (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) está no `.gitignore` por segurança, ele não existe em checkouts novos/outras máquinas — precisa ser recriado manualmente a partir de `.env.example` toda vez.
- **`set -e` dentro de script "sourceado" (`setup-env.sh`)**: como o script é executado com `source` (não como subprocesso), `set -e` passava a valer para o terminal inteiro do usuário, encerrando a sessão quando um comando subsequente (ex: `tofu init` com credenciais vazias) falhava. Corrigido removendo `set -e` do script e trocando `$(dirname "$0")` por `$(dirname "${BASH_SOURCE[0]}")` (forma correta de descobrir a própria localização quando sourceado).
- **Erro 403 `Resource not accessible by integration` no workflow `pr-plan.yml`**: o `GITHUB_TOKEN` automático vem com permissões restritas por padrão. Corrigido adicionando `permissions: { pull-requests: write, contents: read }` explicitamente no job que comenta no PR.