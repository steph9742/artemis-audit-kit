# Guide utilisateur

Commandes à lancer sur la machine du moteur, en `sudo`. `K=/opt/audit-surface/kit/scripts`.

## Accès

Interface web, par tunnel SSH depuis le poste :

```bash
ssh -L 5050:127.0.0.1:5050 utilisateur@moteur
```

Puis http://127.0.0.1:5050. Identifiants :

```bash
sudo grep -E '^FRONTEND_' /opt/audit-surface/artemis/.env
```

## Avant un relevé

- Autorisation écrite couvrant les cibles.
- Sites chez un tiers ou en SaaS : relevé passif, débit de production, dans les limites du contrat.
- Toujours une étiquette, par exemple `essai`, `perimetre-AAAA-MM-JJ`.

## Lancer un relevé

```bash
sudo $K/relever.sh perimetre-2026-10-01 exemple.org 198.51.100.0/24
```

Cibles acceptées : domaine, IP, plage CIDR. Artemis découvre les sous-domaines et les services, puis lance les contrôles sur chacun.

Par l'interface : menu « Add targets », une cible par ligne, renseigner l'étiquette.

Arrêter un relevé et supprimer ses tâches en attente :

```bash
sudo $K/relever.sh --arreter ID_ANALYSE
```

## Suivre

```bash
sudo $K/file.sh              # tâches en attente par relevé, avec leur id
sudo $K/file.sh --attendre   # rend la main quand la file est vide
```

Dans l'interface : « View targets » (relevés) et « Task queue » (file).

Ordre de grandeur : plusieurs dizaines de minutes pour un domaine à 2 requêtes/s. Une charge processeur faible est normale : le relevé attend le réseau.

## Lire les résultats

```bash
sudo $K/synthese.sh              # tous les relevés
sudo $K/synthese.sh ID_ANALYSE   # un relevé
```

La synthèse donne le nombre de résultats, les constats par module et par motif, les cibles concernées et les modules en erreur.

| Statut Artemis | Signification |
|---|---|
| `INTERESTING` | Constat à examiner |
| `OK` | Contrôle passé, rien trouvé |
| `ERROR` | Module en échec : pas un constat, mais un trou de couverture |

Dans l'interface : « View raw task results », filtrable par cible et par module. Rapports par organisme : « Export reports », puis « View exported reports ».

## API

Base : `http://127.0.0.1:5050/api`, en-tête `X-Api-Token` (valeur `API_TOKEN` du `.env`). Documentation interactive : http://127.0.0.1:5050/docs. Ne pas passer le jeton en clair sur une ligne de commande : il finit dans l'historique. Les scripts du kit le lisent eux-mêmes.

| Appel | Usage |
|---|---|
| `POST /api/add` | Corps `{"targets": [...], "tag": "..."}` |
| `GET /api/analyses?tag=` | Relevés, avec `num_pending_tasks` |
| `GET /api/num-queued-tasks` | Taille de la file |
| `GET /api/task-results?only_interesting=true&page=1&page_size=100&analysis_id=` | Constats. Champs utiles : `receiver`, `status`, `status_reason`, `target_string` |
| `POST /api/stop-and-delete-analysis?analysis_id=` | Arrêt d'un relevé |
| `POST /api/archive-tag?tag=` | Archivage d'une étiquette |

## Portée des résultats

Un relevé lancé depuis le réseau interne de l'organisme ne voit pas ce que voit Internet.

| Fiable depuis l'intérieur | Non fiable depuis l'intérieur |
|---|---|
| Sous-domaines (Certificate Transparency) | Ports et services ouverts : le pare-feu interne est traversé |
| Technologies, versions, CMS et extensions | Actifs résolus en IP privée |
| Certificats, TLS, en-têtes | Contenu servi aux seuls visiteurs externes (skimmer, cloaking) |
| Fichiers et outils exposés | |
| SPF, DMARC, expiration des domaines | |

Même depuis une DMZ, l'IP de sortie appartient aux plages de l'organisme : un contenu malveillant qui exclut ces plages reste invisible. Seule une IP hors de ces plages donne le point de vue d'un visiteur quelconque.
