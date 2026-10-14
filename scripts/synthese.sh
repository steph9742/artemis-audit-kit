#!/usr/bin/env bash
# Synthèse des constats d'Artemis, par module et par motif.
#   synthese.sh               tous les relevés
#   synthese.sh ID_ANALYSE    un seul relevé (id donné par file.sh)
set -euo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis

filtre=""
[ -z "${1:-}" ] || filtre="&analysis_id=$1"

read -r -d '' PY_TAILLE <<'PY' || true
import json, sys
print(len(json.load(sys.stdin)))
PY

read -r -d '' PY_SYNTHESE <<'PY' || true
import collections, json, sys

def lire(chemin):
    with open(chemin) as f:
        return [r for ligne in f if ligne.strip() for r in json.loads(ligne)]

interessants = lire(sys.argv[1])
tous = lire(sys.argv[2])
print(f"Résultats : {len(tous)}, dont intéressants : {len(interessants)}\n")

par_motif = collections.Counter(
    (r.get("receiver") or "?", (r.get("status_reason") or "").strip()[:100]) for r in interessants
)
print(f"{'nb':>5}  {'module':30}  motif")
for (module, motif), n in par_motif.most_common():
    print(f"{n:>5}  {module:30}  {motif}")

print("\nCibles :")
for cible, n in collections.Counter(r.get("target_string") or "?" for r in interessants).most_common(30):
    print(f"{n:>5}  {cible}")

erreurs = collections.Counter(r.get("receiver") or "?" for r in tous if r.get("status") == "ERROR")
if erreurs:
    print("\nModules en erreur :")
    for module, n in erreurs.most_common():
        print(f"{n:>5}  {module}")
PY

# Une ligne JSON par page de 500 résultats.
recuperer() {
  local page=1 lot
  while :; do
    lot=$(api_artemis "task-results?only_interesting=$1&page=$page&page_size=500$filtre")
    echo "$lot"
    [ "$(echo "$lot" | python3 -c "$PY_TAILLE")" -eq 500 ] || break
    page=$((page + 1))
  done
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
recuperer true > "$tmp/interessants"
recuperer false > "$tmp/tous"
python3 -c "$PY_SYNTHESE" "$tmp/interessants" "$tmp/tous"
