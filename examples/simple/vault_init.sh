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
    --data '{"policies": "default"}' \
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


 curl --header "X-Vault-Token: $TOKEN" \
       --request POST \
       --data '{"type": "pki", "config": {"default_lease_ttl": "24h", "max_lease_ttl": "87600h"}}' \
       http://127.0.0.1:8200/v1/sys/mounts/pki

curl --header "X-Vault-Token: $TOKEN" \
       --request POST \
       --data '{"common_name": "google.com", "ttl": "87600h"}'\
       http://127.0.0.1:8200/v1/pki/root/generate/internal

curl --header "X-Vault-Token: $TOKEN" \
       --request POST \
       --data '{"allow_any_name": true}' \
       http://127.0.0.1:8200/v1/pki/roles/simple-role

curl \
    --header "X-Vault-Token: $TOKEN" \
    --request POST \
    --data  '{"data":{"foo": "secret-value-for-foo", "bar": 8080}}}' \
    http://127.0.0.1:8200/v1/secret/data/simple-secret

curl \
    --header "X-Vault-Token: $TOKEN" \
    --request PUT \
    --data '{"policy": "CiMgQWxsb3cgdG9rZW5zIHRvIGxvb2sgdXAgdGhlaXIgb3duIHByb3BlcnRpZXMKcGF0aCAiYXV0aC90b2tlbi9sb29rdXAtc2VsZiIgewogICAgY2FwYWJpbGl0aWVzID0gWyJyZWFkIl0KfQoKIyBBbGxvdyB0b2tlbnMgdG8gcmVuZXcgdGhlbXNlbHZlcwpwYXRoICJhdXRoL3Rva2VuL3JlbmV3LXNlbGYiIHsKICAgIGNhcGFiaWxpdGllcyA9IFsidXBkYXRlIl0KfQoKIyBBbGxvdyB0b2tlbnMgdG8gcmV2b2tlIHRoZW1zZWx2ZXMKcGF0aCAiYXV0aC90b2tlbi9yZXZva2Utc2VsZiIgewogICAgY2FwYWJpbGl0aWVzID0gWyJ1cGRhdGUiXQp9CgojIEFsbG93IGEgdG9rZW4gdG8gbG9vayB1cCBpdHMgb3duIGNhcGFiaWxpdGllcyBvbiBhIHBhdGgKcGF0aCAic3lzL2NhcGFiaWxpdGllcy1zZWxmIiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KCiMgQWxsb3cgYSB0b2tlbiB0byBsb29rIHVwIGl0cyByZXN1bHRhbnQgQUNMIGZyb20gYWxsIHBvbGljaWVzLiBUaGlzIGlzIHVzZWZ1bAojIGZvciBVSXMuIEl0IGlzIGFuIGludGVybmFsIHBhdGggYmVjYXVzZSB0aGUgZm9ybWF0IG1heSBjaGFuZ2UgYXQgYW55IHRpbWUKIyBiYXNlZCBvbiBob3cgdGhlIGludGVybmFsIEFDTCBmZWF0dXJlcyBhbmQgY2FwYWJpbGl0aWVzIGNoYW5nZS4KcGF0aCAic3lzL2ludGVybmFsL3VpL3Jlc3VsdGFudC1hY2wiIHsKICAgIGNhcGFiaWxpdGllcyA9IFsicmVhZCJdCn0KCiMgQWxsb3cgYSB0b2tlbiB0byByZW5ldyBhIGxlYXNlIHZpYSBsZWFzZV9pZCBpbiB0aGUgcmVxdWVzdCBib2R5OyBvbGQgcGF0aCBmb3IKIyBvbGQgY2xpZW50cywgbmV3IHBhdGggZm9yIG5ld2VyCnBhdGggInN5cy9yZW5ldyIgewogICAgY2FwYWJpbGl0aWVzID0gWyJ1cGRhdGUiXQp9CnBhdGggInN5cy9sZWFzZXMvcmVuZXciIHsKICAgIGNhcGFiaWxpdGllcyA9IFsidXBkYXRlIl0KfQoKIyBBbGxvdyBsb29raW5nIHVwIGxlYXNlIHByb3BlcnRpZXMuIFRoaXMgcmVxdWlyZXMga25vd2luZyB0aGUgbGVhc2UgSUQgYWhlYWQKIyBvZiB0aW1lIGFuZCBkb2VzIG5vdCBkaXZ1bGdlIGFueSBzZW5zaXRpdmUgaW5mb3JtYXRpb24uCnBhdGggInN5cy9sZWFzZXMvbG9va3VwIiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KCiMgQWxsb3cgYSB0b2tlbiB0byBtYW5hZ2UgaXRzIG93biBjdWJieWhvbGUKcGF0aCAiY3ViYnlob2xlLyoiIHsKICAgIGNhcGFiaWxpdGllcyA9IFsiY3JlYXRlIiwgInJlYWQiLCAidXBkYXRlIiwgImRlbGV0ZSIsICJsaXN0Il0KfQoKIyBBbGxvdyBhIHRva2VuIHRvIHdyYXAgYXJiaXRyYXJ5IHZhbHVlcyBpbiBhIHJlc3BvbnNlLXdyYXBwaW5nIHRva2VuCnBhdGggInN5cy93cmFwcGluZy93cmFwIiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KCiMgQWxsb3cgYSB0b2tlbiB0byBsb29rIHVwIHRoZSBjcmVhdGlvbiB0aW1lIGFuZCBUVEwgb2YgYSBnaXZlbgojIHJlc3BvbnNlLXdyYXBwaW5nIHRva2VuCnBhdGggInN5cy93cmFwcGluZy9sb29rdXAiIHsKICAgIGNhcGFiaWxpdGllcyA9IFsidXBkYXRlIl0KfQoKIyBBbGxvdyBhIHRva2VuIHRvIHVud3JhcCBhIHJlc3BvbnNlLXdyYXBwaW5nIHRva2VuLiBUaGlzIGlzIGEgY29udmVuaWVuY2UgdG8KIyBhdm9pZCBjbGllbnQgdG9rZW4gc3dhcHBpbmcgc2luY2UgdGhpcyBpcyBhbHNvIHBhcnQgb2YgdGhlIHJlc3BvbnNlIHdyYXBwaW5nCiMgcG9saWN5LgpwYXRoICJzeXMvd3JhcHBpbmcvdW53cmFwIiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KCiMgQWxsb3cgZ2VuZXJhbCBwdXJwb3NlIHRvb2xzCnBhdGggInN5cy90b29scy9oYXNoIiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KcGF0aCAic3lzL3Rvb2xzL2hhc2gvKiIgewogICAgY2FwYWJpbGl0aWVzID0gWyJ1cGRhdGUiXQp9CnBhdGggInN5cy90b29scy9yYW5kb20iIHsKICAgIGNhcGFiaWxpdGllcyA9IFsidXBkYXRlIl0KfQpwYXRoICJzeXMvdG9vbHMvcmFuZG9tLyoiIHsKICAgIGNhcGFiaWxpdGllcyA9IFsidXBkYXRlIl0KfQoKIyBBbGxvdyBjaGVja2luZyB0aGUgc3RhdHVzIG9mIGEgQ29udHJvbCBHcm91cCByZXF1ZXN0IGlmIHRoZSB1c2VyIGhhcyB0aGUKIyBhY2Nlc3NvcgpwYXRoICJzeXMvY29udHJvbC1ncm91cC9yZXF1ZXN0IiB7CiAgICBjYXBhYmlsaXRpZXMgPSBbInVwZGF0ZSJdCn0KCnBhdGggInNlY3JldC9kYXRhKiIgewogICAgY2FwYWJpbGl0aWVzID0gWyJjcmVhdGUiLCAicmVhZCIsICJ1cGRhdGUiLCAiZGVsZXRlIiwgImxpc3QiXQp9CgpwYXRoICJwa2kvKiIgewogICAgY2FwYWJpbGl0aWVzID0gWyJjcmVhdGUiLCAicmVhZCIsICJ1cGRhdGUiLCAiZGVsZXRlIiwgImxpc3QiXQp9"}' \
    http://127.0.0.1:8200/v1/sys/policies/acl/default