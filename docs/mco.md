# Maintien en condition opérationnelle

Commandes à lancer sur la machine du moteur, en `sudo`. `K=/opt/audit-surface/kit/scripts`.

## Composants

| Composant | Source | Mise à jour |
|---|---|---|
| Debian | dépôts Debian | `apt` |
| Docker CE et docker compose | `download.docker.com` | `apt` |
| Artemis | `github.com/CERT-Polska/Artemis` (git) et image `certpl/artemis:latest` | procédure ci-dessous |
| Kit | ce dépôt, cloné dans `/opt/audit-surface/kit` | `git pull` |

L'image Artemis n'est pas épinglée : `scripts/start` d'Artemis tire `latest` à chaque exécution.

## Contrôles périodiques

| Fréquence | Contrôle |
|---|---|
| Quotidien | `$K/verifier.sh` (tâche planifiée ci-dessous) |
| Hebdomadaire | `$K/file.sh` : pas de relevé bloqué ; `df -h /` et `docker system df` |
| Mensuel | Mises à jour Debian, Docker et Artemis |
| À chaque mise à jour d'Artemis | Revue des nouveaux modules (intrusifs ou non) |
| Au départ d'une personne ayant eu accès | Rotation des secrets |

Tâche planifiée, résultat dans le journal système :

```bash
cat > /etc/cron.d/audit-surface <<'EOF'
15 7 * * * root /opt/audit-surface/kit/scripts/verifier.sh 2>&1 | logger -t audit-surface
EOF
```

Lecture : `journalctl -t audit-surface --since today`.

## Mises à jour

### Debian et Docker

```bash
apt-get update && apt-get upgrade -y
$K/verifier.sh
```

Après une mise à jour de Docker, les conteneurs redémarrent seuls (`restart: always`). Vérifier quand même.

### Artemis

1. Relever l'état actuel :
   ```bash
   cd /opt/audit-surface/artemis
   git rev-parse HEAD
   docker image inspect certpl/artemis:latest --format '{{index .RepoDigests 0}}'
   ```
2. Mettre à jour le code : `git pull`.
3. Comparer les services : `git diff ANCIEN_COMMIT HEAD -- docker-compose.yaml`. Tout nouveau module `karton-*` qui tente des identifiants, injecte ou fuzze est ajouté à `INTRUSIFS` dans `scripts/commun.sh`, avant l'étape suivante.
4. `$K/generer-surcharge.sh`
5. `./scripts/start --mode=production` (tire la nouvelle image).
6. `$K/verifier.sh`, puis un relevé témoin sur une cible de test.

Retour arrière :

```bash
git checkout ANCIEN_COMMIT
echo 'ARTEMIS_BUILD_IMAGE=certpl/artemis@sha256:ANCIEN_DIGEST' >> .env
$K/generer-surcharge.sh && $K/compose.sh up -d && $K/verifier.sh
```

Retirer `ARTEMIS_BUILD_IMAGE` du `.env` pour revenir à `latest`.

### Kit

```bash
git -C /opt/audit-surface/kit pull
$K/generer-surcharge.sh && $K/compose.sh up -d && $K/verifier.sh
```

## Secrets

Tous dans `/opt/audit-surface/artemis/.env` (root, mode 600), avec une copie dans un gestionnaire de secrets. Jamais dans un dépôt. Commandes à lancer depuis `/opt/audit-surface/artemis`.

| Secret | Utilisé par | Rotation |
|---|---|---|
| `FRONTEND_PASSWORD` | interface web | `sed -i "s/^FRONTEND_PASSWORD=.*/FRONTEND_PASSWORD=$(openssl rand -hex 16)/" .env` |
| `API_TOKEN` | scripts, outils consommateurs | `sed -i "s/^API_TOKEN=.*/API_TOKEN=$(openssl rand -hex 32)/" .env`, puis mise à jour des consommateurs |
| `WORDFENCE_API_KEY` | module `wordpress_plugins` | depuis le compte Wordfence |

Après rotation : `$K/compose.sh up -d --force-recreate`.

Saisie d'une clé sans qu'elle apparaisse à l'écran ni dans l'historique :

```bash
read -rsp "Clé : " K_ && sed -i '/^WORDFENCE_API_KEY=/d' .env && printf 'WORDFENCE_API_KEY=%s\n' "$K_" >> .env && unset K_
```

## Sauvegarde

| Élément | Sauvegarde |
|---|---|
| `.env` | Gestionnaire de secrets, à chaque modification |
| Kit | Dépôt git |
| Règles `DOCKER-USER` | `/etc/iptables/rules.v4` |
| Résultats des relevés | Aucune : ils sont récupérés par l'outil consommateur, qui est le dépôt durable |

## Purge

- Journaux de tâches : automatique après `REMOVE_LOGS_AFTER_DAYS` jours.
- Archivage d'une étiquette : `POST /api/archive-tag?tag=ETIQUETTE`.
- Suppression de tous les résultats : `$K/compose.sh down -v`. Irréversible.

## Reconstruction

1. Debian, une seule passerelle par défaut, de préférence sur l'interface dédiée aux relevés.
2. SSH limité à l'interface d'administration :
   ```bash
   echo "ListenAddress ADRESSE_ADMIN" >> /etc/ssh/sshd_config && sshd -t && systemctl reload ssh
   ```
3. Docker :
   ```bash
   apt-get update && apt-get install -y ca-certificates curl git gnupg python3
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
   chmod a+r /etc/apt/keyrings/docker.asc
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
   apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
4. Kit : `git clone https://github.com/steph9742/artemis-audit-kit /opt/audit-surface/kit`.
5. Configuration :
   - restauration : cloner Artemis (`git clone https://github.com/CERT-Polska/Artemis /opt/audit-surface/artemis`), puis copier le `.env` sauvegardé dans `/opt/audit-surface/artemis/.env`, mode 600 ;
   - installation neuve : rien, `installer.sh` génère les secrets.
6. `$K/installer.sh`
7. Accès d'un consommateur : [exploitation](exploitation.md#accès-dun-outil-consommateur-à-lapi).
8. `$K/verifier.sh` et relevé témoin.
