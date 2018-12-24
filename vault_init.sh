#!/bin/bash

# usage: . ./vault_init.sh

TOKEN="Dzje67e6pyj3Wh1DqBBMAYYM"

curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '{"type": "approle"}' \
    http://127.0.0.1:8200/v1/sys/auth/approle

curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data '{"policies": "dev-policy,test-policy"}' \
    http://127.0.0.1:8200/v1/auth/approle/role/tester

export ROLE_ID=$(curl \
    --silent \
    --header "X-Vault-Token: $TOKEN" \
    http://127.0.0.1:8200/v1/auth/approle/role/tester/role-id \
    | jq -r '.data.role_id')

export SECRET_ID="$(curl \
    --silent \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
     http://127.0.0.1:8200/v1/auth/approle/role/tester/secret-id \
    | jq -r '.data.secret_id')"