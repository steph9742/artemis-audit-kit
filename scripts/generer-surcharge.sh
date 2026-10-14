#!/usr/bin/env bash
# Génère $ARTEMIS_DIR/surcharge/docker-compose.yml. Le script find_docker_compose_files
# d'Artemis inclut tout */docker-compose.yml : la surcharge s'applique à chaque démarrage.
#
# Variables lues dans le .env d'Artemis :
#   AUDIT_PORT_WEB    port de l'interface et de l'API sur l'hôte (défaut 5050)
#   AUDIT_BIND_EXTRA  adresse supplémentaire de publication de l'API (défaut : aucune)
#   AUDIT_DNS         résolveurs des conteneurs, séparés par des virgules (défaut 9.9.9.9,1.1.1.1)
set -euo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis

port=$(port_web)
bind_extra=$(env_artemis AUDIT_BIND_EXTRA)
dns=$(env_artemis AUDIT_DNS)
dns=${dns:-9.9.9.9,1.1.1.1}

services=()
while IFS= read -r s; do services+=("$s"); done < <(awk '
  /^services:/ { dans = 1; next }
  /^[^ #]/     { dans = 0 }
  dans && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { sub(/^  /, ""); sub(/:.*/, ""); print }
' "$ARTEMIS_DIR/docker-compose.yaml")

if [ "${#services[@]}" -lt 10 ]; then
  echo "${#services[@]} services lus dans docker-compose.yaml : format inattendu." >&2
  exit 1
fi

dns_yaml=$(echo "$dns" | sed 's/[^,]*/"&"/g; s/,/, /g')
ports_yaml="\"127.0.0.1:$port:5000\""
[ -z "$bind_extra" ] || ports_yaml="$ports_yaml, \"$bind_extra:$port:5000\""

mkdir -p "$ARTEMIS_DIR/surcharge"
{
  echo "# Généré par generer-surcharge.sh. Ne pas modifier à la main."
  echo "services:"
  for s in "${services[@]}"; do
    echo "  $s:"
    echo "    dns: [$dns_yaml]"
    if est_intrusif "$s"; then
      echo "    profiles: !override [\"jamais\"]"
    fi
    if [ "$s" = web ]; then
      echo "    ports: !override [$ports_yaml]"
    fi
    # Aucune politique de redémarrage d'origine. S'il s'arrête, karton-system ne stocke
    # plus les tâches et le moteur se fige sans erreur visible.
    if [ "$s" = s3mock ]; then
      echo "    restart: always"
    fi
  done
} > "$ARTEMIS_DIR/surcharge/docker-compose.yml"

for s in "${INTRUSIFS[@]}"; do
  printf '%s\n' "${services[@]}" | grep -qx "$s" || echo "info : $s absent de cette version d'Artemis"
done
echo "Surcharge écrite : ${#services[@]} services, publication [$ports_yaml], DNS [$dns_yaml]."
