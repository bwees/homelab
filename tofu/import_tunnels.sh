#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="5e2ba2ec4aedeea294c2bf45f28c6414"
ZONE_ID="72e8e948ac04faef676a0a877bab6f9d"
TUNNELS=(eridani hail-mary stepien tau-ceti)

TOKEN=$(op read "op://Homelab Deployment/tofu-credentials/cloudflare/api_token")

api() {
  curl -s "https://api.cloudflare.com/client/v4/$1" -H "Authorization: Bearer $TOKEN"
}

for name in "${TUNNELS[@]}"; do
  tunnel_id=$(api "accounts/$ACCOUNT_ID/cfd_tunnel?name=$name&is_deleted=false" \
    | jq -r '.result[0].id // empty')
  record_id=$(api "zones/$ZONE_ID/dns_records?type=CNAME&name=$name.tun.bwees.io" \
    | jq -r '.result[0].id // empty')

  [[ -n "$tunnel_id" ]] \
    && echo "tofu import 'cloudflare_zero_trust_tunnel_cloudflared.tunnels[\"$name\"]' '$ACCOUNT_ID/$tunnel_id'" \
    || echo "# no tunnel found for $name" >&2

  [[ -n "$record_id" ]] \
    && echo "tofu import 'cloudflare_dns_record.tunnels[\"$name\"]' '$ZONE_ID/$record_id'" \
    || echo "# no DNS record found for $name.tun" >&2
done
