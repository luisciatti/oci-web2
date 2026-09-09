# Layer: core/foundation

## Objetivo
Bootstrap único da infraestrutura — cria o backend de state remoto e o usuário de serviço usado por todas as outras layers e pelo CI/CD. É a única layer aplicada sempre manualmente, nunca via pipeline (paradoxo "ovo e galinha": não existe backend remoto para guardar o state que cria o backend remoto).

## Recursos criados
| Recurso | Nome | Propósito |
|---|---|---|
| `oci_objectstorage_bucket` | `oci-testhub-tfstate` | Guarda os `.tfstate` de todas as layers seguintes (S3-compatible) |
| `oci_identity_group` | `grp-automation` | Grupo de automação |
| `oci_identity_user` | `svc-github-actions` | Usuário de serviço usado pelo GitHub Actions e localmente |
| `oci_identity_user_group_membership` | — | Associa o usuário ao grupo |
| `oci_identity_policy` | `policy-automation` | `Allow group grp-automation to manage all-resources in tenancy` |

## State
Local (`terraform.tfstate` na própria pasta) — não usa backend remoto, propositalmente.

## Decisões e por quês
- **Sem compartment próprio**: bucket criado direto no compartment raiz do tenancy, para simplificar (o compartment de aplicação vem só na layer `global`).
- **Policy ampla (`manage all-resources in tenancy`)**: aceitável para ambiente de estudo/single-tenant; em produção seria restrita por compartment. Registrado como débito técnico consciente.
- **`email` obrigatório em `oci_identity_user`**: a API do Identity Domain exige o campo, mesmo para usuário de serviço (não precisa ser uma caixa real, só formato válido).

## Credenciais geradas manualmente (não via Terraform)
Depois do `apply`, geramos manualmente pelo console (por segurança, chave privada não deve transitar por state/código):
- **API Key** (par de chaves) → usada pelo provider `oci` (localmente via `~/.oci/config`, no CI via secrets)
- **Customer Secret Key** → usada especificamente pelo backend S3-compatible (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, mesmo sendo credencial OCI — ver nota abaixo)

## Por que variáveis `AWS_*` numa infra 100% OCI?
A Object Storage da OCI expõe uma API compatível com S3. O backend `s3` do OpenTofu foi construído com o SDK da AWS por baixo dos panos, que sempre procura credenciais nessas variáveis de ambiente por convenção própria — não tem nada de AWS real envolvido, é só o formato de credencial que o backend espera.

## Bugs/gotchas descobertos aqui
- **`SignatureDoesNotMatch` no backend S3**: o SDK da AWS (usado pelo backend) passou a calcular checksums automaticamente, o que a OCI (S3-compatible, mas não 100% idêntica) não valida do mesmo jeito. Correção: `skip_s3_checksum = true` no backend **+** variáveis de ambiente `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` e `AWS_RESPONSE_CHECKSUM_VALIDATION=when_required` (o flag sozinho não resolveu, foi preciso as duas coisas).
- **`force_path_style` deprecado** → trocado por `use_path_style`.

## GitHub Secrets criados (Environment `teste-hub`)
```
OCI_TENANCY_OCID
OCI_USER_OCID
OCI_FINGERPRINT
OCI_PRIVATE_KEY
OCI_REGION
AWS_ACCESS_KEY_ID       (Customer Secret Key — access)
AWS_SECRET_ACCESS_KEY   (Customer Secret Key — secret)
OCI_NAMESPACE
```

## Outputs
Nenhum output relevante consumido por outras layers ainda (o bucket é referenciado pelo nome fixo no `backend` de cada layer, não via `terraform_remote_state`).