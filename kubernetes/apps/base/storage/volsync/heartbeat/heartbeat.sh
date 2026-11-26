#!/bin/sh
set -eu

GRACE_SECONDS=7200
ENDPOINT_KEY="backups_volsync-$CLUSTER"

now=$(date -u +%s)
problems=""

sources=$(kubectl get replicationsources --all-namespaces \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}|{.status.nextSyncTime}|{.status.latestMoverStatus.result}{"\n"}{end}')

while IFS='|' read -r name next result; do
  [ -n "$name" ] || continue
  if [ "$result" = "Failed" ]; then
    problems="$problems$name failed; "
  elif [ -n "$next" ] && [ "$now" -gt $(($(date -u -D '%Y-%m-%dT%H:%M:%SZ' -d "$next" +%s) + GRACE_SECONDS)) ]; then
    problems="$problems$name overdue since $next; "
  fi
done <<EOF
$sources
EOF

push() {
  curl -fsS -X POST -G -H "Authorization: Bearer $GATUS_TOKEN" "$@" "$GATUS_URL/api/v1/endpoints/$ENDPOINT_KEY/external"
}

if [ -z "$problems" ]; then
  push --data-urlencode success=true
else
  echo "$problems"
  push --data-urlencode success=false --data-urlencode "error=$problems"
fi
