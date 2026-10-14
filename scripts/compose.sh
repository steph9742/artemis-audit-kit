#!/usr/bin/env bash
# docker compose sur la pile Artemis, surcharge comprise.
# Exemples : compose.sh ps    compose.sh logs -f karton-system    compose.sh up -d
set -euo pipefail
. "$(dirname "$0")/commun.sh"
exiger_artemis
artemis_compose "$@"
