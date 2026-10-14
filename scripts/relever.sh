#!/usr/bin/env bash
# Lance ou arrête un relevé.
#   relever.sh ETIQUETTE CIBLE [CIBLE...]    cibles : domaine, IP ou plage CIDR
#   relever.sh --arreter ID_ANALYSE          arrête le relevé et supprime ses tâches en attente
set -euo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis

if [ "${1:-}" = --arreter ]; then
  api_artemis "stop-and-delete-analysis?analysis_id=${2:?usage : relever.sh --arreter ID_ANALYSE}" '{}'
  echo
  exit 0
fi

if [ "$#" -lt 2 ]; then
  echo "usage : $0 ETIQUETTE CIBLE [CIBLE...]  |  $0 --arreter ID_ANALYSE" >&2
  exit 2
fi

etiquette=$1
shift
corps=$(python3 -c 'import json, sys; print(json.dumps({"tag": sys.argv[1], "targets": sys.argv[2:]}))' "$etiquette" "$@")
api_artemis add "$corps"
echo
