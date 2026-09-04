#!/usr/bin/env bash
# IMPORTANTE: este script deve ser executado com "source setup-env.sh",
# nunca com "./setup-env.sh" — ele exporta variáveis para o seu shell atual.
#
# Propositalmente SEM "set -e": como o script é "sourceado", qualquer
# set -e/set -u aqui passaria a valer para o seu terminal inteiro,
# podendo encerrá-lo em caso de erro de um comando não relacionado.

ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/.env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "Aviso: layer/.env não encontrado. Crie a partir de layer/.env.example"
fi

export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

echo "Ambiente configurado. AWS_ACCESS_KEY_ID length: ${#AWS_ACCESS_KEY_ID}"