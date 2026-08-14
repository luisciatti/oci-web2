#!/usr/bin/env bash
set -e

# Carrega credenciais AWS-style (backend S3-compatible) de um arquivo local, não commitado
if [ -f "$(dirname "$0")/.env" ]; then
  source "$(dirname "$0")/.env"
else
  echo "Aviso: layer/.env não encontrado. Crie a partir de layer/.env.example"
fi

export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required

echo "Ambiente configurado. AWS_ACCESS_KEY_ID length: ${#AWS_ACCESS_KEY_ID}"