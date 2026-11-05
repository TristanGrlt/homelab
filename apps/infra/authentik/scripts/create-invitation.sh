#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <admin|operator|user> [email-address]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

: "${AUTHENTIK_URL:?Set AUTHENTIK_URL, for example https://authentik.home.grltt.fr}"
: "${AUTHENTIK_TOKEN:?Set AUTHENTIK_TOKEN to an Authentik API token}"

case "$1" in
  admin) FLOW_SLUG=homelab-enrollment-admin ;;
  operator) FLOW_SLUG=homelab-enrollment-operator ;;
  user) FLOW_SLUG=homelab-enrollment-user ;;
  *)
    echo "Role must be admin, operator, or user" >&2
    exit 2
    ;;
esac

API="$AUTHENTIK_URL/api/v3"
AUTH_HEADER="Authorization: Bearer $AUTHENTIK_TOKEN"
FLOW_QUERY=$(printf '%s' "$FLOW_SLUG" | jq -sRr @uri)
FLOW_UUID=$(
  curl --fail-with-body --silent --show-error \
    "$API/flows/instances/?slug=$FLOW_QUERY" \
    -H "$AUTH_HEADER" |
    jq -er '.results | if length == 1 then .[0].pk else error("expected exactly one matching flow") end'
)

INVITATION=$(
  jq -n \
    --arg flow "$FLOW_UUID" \
    --arg name "homelab-$1-$(date +%s)" \
    '{
      name: $name,
      flow: $flow,
      single_use: true,
      expires: ((now + 86400) | todateiso8601)
    }' |
  curl --fail-with-body --silent --show-error \
    -X POST "$API/stages/invitation/invitations/" \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    --data-binary @- |
  jq -er '.pk'
)

INVITATION_URL="$AUTHENTIK_URL/if/flow/$FLOW_SLUG/?itoken=$INVITATION"

if [ "$#" -eq 2 ]; then
  jq -n --arg email "$2" '{email_addresses: [$email]}' |
    curl --fail-with-body --silent --show-error \
      -X POST "$API/stages/invitation/invitations/$INVITATION/send_email/" \
      -H "$AUTH_HEADER" \
      -H "Content-Type: application/json" \
      --data-binary @- >/dev/null
  echo "Invitation email sent to $2"
fi

echo "$INVITATION_URL"
