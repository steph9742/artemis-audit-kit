#!/usr/bin/env bash
# File de tâches d'Artemis.
#   file.sh                 tâches en attente par relevé
#   file.sh --attendre      affiche le total toutes les 30 s jusqu'à file vide
#   file.sh --mesurer N     tâches traitées en N secondes
set -euo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis

read -r -d '' PY_TOTAL <<'PY' || true
import json, sys
print(sum(a["num_pending_tasks"] for a in json.load(sys.stdin)))
PY

read -r -d '' PY_LISTE <<'PY' || true
import json, sys
analyses = json.load(sys.stdin)
print(f"{'attente':>7}  {'lancé le':16}  {'étiquette':15}  {'id':36}  cible")
for a in sorted(analyses, key=lambda a: a["created_at"]):
    print(f"{a['num_pending_tasks']:>7}  {a['created_at'][:16]}  {a.get('tag') or '-':15}  {a['id']}  {a['target']}")
PY

total() { api_artemis analyses | python3 -c "$PY_TOTAL"; }

case "${1:-}" in
  "")
    api_artemis analyses | python3 -c "$PY_LISTE"
    ;;
  --attendre)
    while n=$(total); [ "$n" -gt 0 ]; do
      echo "$(date +%H:%M:%S)  $n tâches en attente"
      sleep 30
    done
    echo "$(date +%H:%M:%S)  file vide"
    ;;
  --mesurer)
    duree=${2:?usage : file.sh --mesurer SECONDES}
    a=$(total); sleep "$duree"; b=$(total)
    echo "$((a - b)) tâches traitées en $duree s, $b en attente"
    ;;
  *)
    echo "usage : $0 [--attendre | --mesurer SECONDES]" >&2
    exit 2
    ;;
esac
