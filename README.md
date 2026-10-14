# artemis-audit-kit

Déploiement encadré d'[Artemis](https://github.com/CERT-Polska/Artemis) (CERT Polska) pour auditer la surface exposée d'un organisme : sous-domaines, technologies et versions, CMS et extensions, fichiers et outils exposés, certificats, en-têtes, DNS.

Le kit ne modifie pas Artemis. Il ajoute une surcharge Docker Compose, des garde-fous vérifiables et des outils d'exploitation en ligne de commande.

## Ce que le kit apporte

- **Modules intrusifs jamais démarrés** : force brute d'identifiants, injections SQL, de commandes et LFI, XSS. Les conteneurs ne sont pas créés ; ils ne sont pas seulement décochés dans l'interface.
- **Interface et API sur `127.0.0.1`**, plus une adresse optionnelle pour un outil consommateur. Jamais sur toutes les interfaces.
- **Résolveurs DNS publics** dans les conteneurs, pour éviter une vue DNS interne.
- **Redémarrage automatique de `s3mock`**, absent d'origine : son arrêt fige le moteur sans erreur visible.
- **Vérification** en six contrôles, rejouable après chaque démarrage.
- **Outils** pour lancer un relevé, suivre la file, produire une synthèse, sans exposer le jeton d'API sur la ligne de commande.

## Prérequis

- Debian 13 ou équivalent, x86_64
- Docker CE, docker compose 2.24.4 ou plus
- 16 Go de RAM, 30 Go de disque
- Sortie HTTP/HTTPS directe, sans proxy ni inspection TLS

## Installation

```bash
sudo git clone https://github.com/steph9742/artemis-audit-kit /opt/audit-surface/kit
sudo /opt/audit-surface/kit/scripts/installer.sh
```

Puis renseigner le contact dans `CUSTOM_USER_AGENT` (`/opt/audit-surface/artemis/.env`) et relancer `scripts/verifier.sh`.

## Utilisation

```bash
K=/opt/audit-surface/kit/scripts
sudo $K/relever.sh essai exemple.org        # lancer un relevé, étiquette « essai »
sudo $K/file.sh --attendre                 # attendre la fin
sudo $K/synthese.sh                        # constats par module et par motif
```

Interface : `ssh -L 5050:127.0.0.1:5050 utilisateur@moteur`, puis http://127.0.0.1:5050.

## Contenu

| Chemin | Rôle |
|---|---|
| `scripts/installer.sh` | Installation sur une machine neuve |
| `scripts/generer-surcharge.sh` | Surcharge Docker Compose : publication, DNS, modules intrusifs, `s3mock` |
| `scripts/verifier.sh` | Contrôle des garde-fous |
| `scripts/relever.sh` | Lancer ou arrêter un relevé |
| `scripts/file.sh` | File de tâches : état, attente, débit |
| `scripts/synthese.sh` | Synthèse des constats |
| `scripts/compose.sh` | `docker compose` sur la pile Artemis, surcharge comprise |
| `config/env.audit` | Configuration ajoutée au `.env` d'Artemis |

## Documentation

- [Guide utilisateur](docs/utilisateur.md) : relevés, résultats, API, portée
- [Exploitation](docs/exploitation.md) : commandes, réglages, débit, incidents
- [MCO](docs/mco.md) : mises à jour, secrets, sauvegarde, reconstruction

## Cadre d'utilisation

N'auditer que des cibles pour lesquelles une autorisation écrite existe. Pour les sites hébergés chez un tiers, le contrat d'hébergement prime. Garder un débit bas, identifier le trafic par le user-agent, et publier une page qui explique les relevés.

## Limites

Artemis ne couvre pas l'inventaire Magento et PrestaShop, l'intégrité des scripts JavaScript par rapport à leurs versions de référence, ni les portes dérobées placées sous des noms de fichiers légitimes. Un site sans constat n'est pas un site sain.

## Crédits

[Artemis](https://github.com/CERT-Polska/Artemis), CERT Polska, licence BSD-3-Clause.
