#!/bin/bash
set -euo pipefail

API_BASE="https://api.tailscale.com/api/v2"

# OAuth
ACCESS_TOKEN="$(
  curl -sf \
    -u "$TS_CLIENT_ID:$TS_CLIENT_SECRET" \
    -d "grant_type=client_credentials" \
    "https://api.tailscale.com/api/v2/oauth/token" \
  | jq -r '.access_token'
)"

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo "Failed to obtain OAuth access token" >&2
  exit 1
fi

echo "Obtained OAuth access token"

auth_hdr=(-H "Authorization: Bearer $ACCESS_TOKEN")

# Apply configurations
curl -sf \
  -o /dev/null \
  "${auth_hdr[@]}" \
  -H "Content-Type: application/json" \
  --data-binary @acl.hujson \
  -X POST \
  "$API_BASE/tailnet/$TS_TAILNET/acl"

echo "Tailscale ACLs applied successfully"

curl -sf \
  -o /dev/null \
  "${auth_hdr[@]}" \
  -H "Content-Type: application/json" \
  --data-binary @dns.json \
  -X POST \
  "$API_BASE/tailnet/$TS_TAILNET/dns/configuration"

echo "Tailscale DNS applied successfully"