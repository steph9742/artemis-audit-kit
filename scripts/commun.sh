# Fonctions communes aux scripts. Usage : . "$(dirname "$0")/commun.sh"

ARTEMIS_DIR="${ARTEMIS_DIR:-/opt/audit-surface/artemis}"

# Modules Artemis jamais démarrés : force brute d'identifiants, injections, XSS.
INTRUSIFS=(
  karton-admin_panel_login_bruter
  karton-wordpress_bruter
  karton-ftp_bruter
  karton-mysql_bruter
  karton-postgresql_bruter
  karton-ssh_bruter
  karton-sql_injection_detector
  karton-command_injection_detector
  karton-lfi_detector
  karton-orm_injection_detector
  karton-xss_scanner
  karton-api_scanner
  karton-example
)

exiger_artemis() {
  [ -f "$ARTEMIS_DIR/docker-compose.yaml" ] && [ -f "$ARTEMIS_DIR/.env" ] && return 0
  echo "Artemis absent ou non configuré dans $ARTEMIS_DIR (variable ARTEMIS_DIR)." >&2
  exit 1
}

est_intrusif() {
  local s
  for s in "${INTRUSIFS[@]}"; do [ "$s" = "$1" ] && return 0; done
  return 1
}

# Valeur d'une variable du .env d'Artemis, sans guillemets. Vide si absente.
env_artemis() {
  { grep -E "^$1=" "$ARTEMIS_DIR/.env" || true; } | tail -n 1 | cut -d= -f2- \
    | sed -E "s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/"
}

port_web() {
  local p
  p=$(env_artemis AUDIT_PORT_WEB)
  echo "${p:-5050}"
}

# docker compose avec les fichiers et le profil qu'utilise scripts/start d'Artemis.
artemis_compose() {
  local fichiers profil=()
  fichiers=$(cd "$ARTEMIS_DIR" && scripts/find_docker_compose_files --mode=production --docker-compose-string)
  [[ $(uname -m) == arm* ]] || profil=(--profile not-arm)
  # $fichiers est une liste « -f a -f b » : découpage voulu.
  (cd "$ARTEMIS_DIR" && docker compose $fichiers ${profil[@]+"${profil[@]}"} "$@")
}

# Appel à l'API d'Artemis. Le jeton passe par un descripteur, pas par la ligne de commande.
#   api_artemis CHEMIN                 GET
#   api_artemis CHEMIN CORPS_JSON      POST
api_artemis() {
  local options=()
  [ -z "${2:-}" ] || options=(-X POST -H 'Content-Type: application/json' -d "$2")
  curl -fsS -H @<(printf 'X-Api-Token: %s\n' "$(env_artemis API_TOKEN)") \
    ${options[@]+"${options[@]}"} "http://127.0.0.1:$(port_web)/api/$1"
}
