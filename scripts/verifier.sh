#!/usr/bin/env bash
# Contrôle les garde-fous du moteur. Code de sortie : nombre de contrôles en échec.
# À lancer après chaque démarrage, mise à jour ou changement de configuration.
set -uo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis

echecs=0
ok()    { echo "  OK     $*"; }
echec() { echo "  ÉCHEC  $*"; echecs=$((echecs + 1)); }

echo "1. Surcharge"
if [ -f "$ARTEMIS_DIR/surcharge/docker-compose.yml" ]; then
  ok "surcharge/docker-compose.yml présent"
else
  echec "surcharge/docker-compose.yml absent : lancer generer-surcharge.sh"
fi

echo "2. Services"
if ! en_cours=$(artemis_compose ps --services --status running 2>&1); then
  echec "docker compose ps : $en_cours"
  en_cours=""
elif [ -z "$en_cours" ]; then
  echec "aucun service en cours"
else
  ok "$(echo "$en_cours" | wc -l) services en cours"
  intrus=""
  for s in $en_cours; do
    if est_intrusif "$s"; then intrus="$intrus $s"; fi
  done
  if [ -z "$intrus" ]; then ok "aucun module intrusif"; else echec "modules intrusifs en cours :$intrus"; fi
  for s in web redis postgres s3mock karton-system; do
    echo "$en_cours" | grep -qx "$s" || echec "$s arrêté"
  done
fi

echo "3. Publication de l'interface"
autorises="127.0.0.1 $(env_artemis AUDIT_BIND_EXTRA)"
id_web=$(artemis_compose ps -q web 2>/dev/null)
publie=""
[ -z "$id_web" ] || publie=$(docker port "$id_web" 5000/tcp 2>/dev/null)
if [ -z "$publie" ]; then
  echec "web ne publie aucun port"
else
  while read -r adresse; do
    case " $autorises " in
      *" ${adresse%:*} "*) ok "écoute sur $adresse" ;;
      *)                   echec "écoute non autorisée sur $adresse" ;;
    esac
  done <<< "$publie"
fi

echo "4. Configuration"
ua=$(env_artemis CUSTOM_USER_AGENT)
case "$ua" in
  "")            echec "CUSTOM_USER_AGENT vide" ;;
  *example.org*) echec "CUSTOM_USER_AGENT : contact à renseigner" ;;
  *)             ok "user-agent : $ua" ;;
esac
jeton=$(env_artemis API_TOKEN)
if [ "${#jeton}" -ge 32 ]; then ok "jeton d'API défini"; else echec "API_TOKEN absent ou trop court (32 caractères minimum)"; fi
rps=$(env_artemis REQUESTS_PER_SECOND)
if [ -n "$rps" ] && [ "$rps" != 0 ]; then ok "REQUESTS_PER_SECOND=$rps"; else echec "REQUESTS_PER_SECOND absent ou nul (débit illimité)"; fi

echo "5. Résolution DNS publique depuis un conteneur"
if r=$(artemis_compose exec -T web python3 -c "import socket; print(socket.gethostbyname('crt.sh'))" </dev/null 2>&1); then
  ok "crt.sh -> $r"
else
  echec "$(echo "$r" | tail -n 1)"
fi

echo "6. Stockage des tâches"
if artemis_compose logs --since 5m karton-system 2>&1 | grep -q 'Could not connect to the endpoint'; then
  echec "karton-system ne joint pas s3mock : les tâches ne progressent plus"
else
  ok "aucune erreur de stockage dans les 5 dernières minutes"
fi

echo
if [ "$echecs" -eq 0 ]; then echo "Tous les contrôles sont OK."; else echo "$echecs contrôle(s) en échec : ne pas lancer de relevé."; fi
exit "$echecs"
