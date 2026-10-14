#!/usr/bin/env bash
# Installe Artemis et la configuration du kit sur une machine neuve.
# Usage : sudo [ARTEMIS_DIR=/opt/audit-surface/artemis] scripts/installer.sh
#
# Sur une installation existante, le .env n'est pas modifié.
set -euo pipefail
ICI=$(cd "$(dirname "$0")" && pwd)
. "$ICI/commun.sh"

echo "== Prérequis"
for c in docker git curl openssl python3; do
  command -v "$c" >/dev/null || { echo "$c absent" >&2; exit 1; }
done
v=$(docker compose version --short | sed 's/^v//')
# La surcharge utilise la balise YAML !override.
if [ "$(printf '%s\n2.24.4\n' "$v" | sort -V | head -n 1)" != 2.24.4 ]; then
  echo "docker compose $v : version 2.24.4 minimum" >&2
  exit 1
fi
mem=$(awk '/MemTotal/ { printf "%d", $2 / 1024 / 1024 }' /proc/meminfo)
[ "$mem" -ge 15 ] || echo "Attention : $mem Go de RAM, Artemis en demande 16."
[ "$(uname -m)" = x86_64 ] || echo "Attention : architecture $(uname -m), certains modules ne démarreront pas."

echo "== Artemis"
[ -d "$ARTEMIS_DIR/.git" ] || git clone https://github.com/CERT-Polska/Artemis "$ARTEMIS_DIR"
echo "commit $(git -C "$ARTEMIS_DIR" rev-parse --short HEAD)"

echo "== Configuration"
env="$ARTEMIS_DIR/.env"
[ -f "$env" ] || cp "$ARTEMIS_DIR/env.example" "$env"
if grep -q '^AUDIT_PORT_WEB=' "$env"; then
  echo ".env déjà configuré, laissé tel quel."
else
  # env.example déclare des identifiants vides qui feraient doublon.
  sed -i '/^FRONTEND_USERNAME=$/d; /^FRONTEND_PASSWORD=$/d' "$env"
  { echo; cat "$ICI/../config/env.audit"; } >> "$env"
  sed -i -e "s/^FRONTEND_PASSWORD=__GENERE__\$/FRONTEND_PASSWORD=$(openssl rand -hex 16)/" \
         -e "s/^API_TOKEN=__GENERE__\$/API_TOKEN=$(openssl rand -hex 32)/" "$env"
fi
chmod 600 "$env"

"$ICI/generer-surcharge.sh"

echo "== Démarrage"
"$ARTEMIS_DIR/scripts/start" --mode=production

echo "Identifiants de l'interface et jeton d'API : $env (FRONTEND_USERNAME, FRONTEND_PASSWORD, API_TOKEN)."
echo "Renseigner le contact dans CUSTOM_USER_AGENT avant le premier relevé."
echo "== Vérification"
"$ICI/verifier.sh"
