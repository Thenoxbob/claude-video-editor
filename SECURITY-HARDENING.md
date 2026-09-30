# Version sécurisée de claude-video-editor

Copie du dépôt `assafkip/claude-video-editor` (commit `3f07b69`, 11 juin 2026),
auditée puis renforcée le 30 septembre 2026. Toutes les modifications sont dans
l'historique git (`git log`, `git diff 3f07b69`).

## Résultat de l'audit du code d'origine

Aucun code malveillant trouvé : pas de hooks, pas de serveur MCP, pas de code
obfusqué, un seul service contacté par le code Python (`api.elevenlabs.io`),
commandes ffmpeg lancées sans shell. Les risques venaient des dépendances et de
la configuration, d'où les correctifs ci-dessous.

## Ce qui a été changé

| # | Problème d'origine | Correctif |
|---|---|---|
| 1 | 127 appels `npx hyperframes` **sans version** : Claude aurait téléchargé la dernière version publiée par HeyGen (mises à jour quasi quotidiennes), sans confirmation. Deux autres versions (0.6.70 / 0.6.88) mélangées ailleurs. | Toutes les commandes sont figées sur **`hyperframes@0.8.96`** (177 occurrences), y compris les commandes « nues » (`hyperframes add…`). Une règle en tête de chaque skill interdit toute autre version. |
| 2 | La version testée par l'auteur (0.6.88) embarque **6 vulnérabilités « high »** (`npm audit` : adm-zip, extract-zip, sharp/libvips, puppeteer) et 218 paquets, dont 5 avec scripts d'installation (l'un télécharge un binaire depuis nuget.org). | Passage à la **0.8.96** : 0 vulnérabilité connue, 123 paquets, 1 seul script d'installation (esbuild). Compatibilité vérifiée : lint + rendu MP4 réel des 3 compositions fournies, et remplacement de texte via `--variables`. |
| 3 | **Télémétrie HyperFrames activée par défaut** (envoi d'événements d'usage à PostHog). | L'installeur exécute `hyperframes telemetry disable` (réglage permanent). Sous Windows, il définit aussi `HYPERFRAMES_NO_TELEMETRY`, `HYPERFRAMES_NO_UPDATE_CHECK` et `HYPERFRAMES_NO_AUTO_INSTALL` pour votre compte. |
| 4 | Commandes qui envoient vers HeyGen ou le cloud (`publish`, `auth`, `cloud`, `lambda`, `cloudrun`) utilisables librement. | Interdites à Claude sauf demande explicite de votre part. |
| 5 | Registre de composants lu depuis la branche `main` de HeyGen (contenu modifiable à tout moment). | Figé sur le tag `v0.8.96`. |
| 6 | Dépendances Python sans version, dont `librosa` et `matplotlib`, **jamais importées** mais qui tiraient une quarantaine de paquets. | Réduit aux 3 paquets réellement utilisés (`requests`, `numpy`, `Pillow`), soit 8 au total. Versions exactes avec **empreintes SHA-256** dans `skills/video-use/requirements.lock`, installées avec `--require-hashes --only-binary=:all:`. |
| 7 | Les skills ne disaient pas à Claude d'utiliser l'environnement Python isolé : risque de `pip install` non vérifiés dans le Python du système. | Règle ajoutée : utiliser `skills\video-use\.venv\Scripts\python.exe` (Windows) ou `.venv/bin/python`, et ne jamais faire de `pip install` dans le système. |
| 8 | Clé ElevenLabs saisie en clair et stockée sans restriction de droits. | Saisie masquée. Fichier `.env` lisible par votre compte seul (`icacls` sous Windows, `chmod 600` sinon). Rien n'est écrit si la clé est déjà dans une variable d'environnement. |
| 9 | `skills/video-use/install.md` demandait à Claude de cloner **un autre dépôt** (non figé) dans `~/Developer`, de l'installer dans `~/.claude/skills` et de le mettre à jour par `git pull`. Le README associé invitait à coller la clé API dans la conversation. | Fichier neutralisé, instructions supprimées. |
| 10 | GSAP et dotlottie chargés depuis le CDN jsDelivr sans contrôle d'intégrité. | Attribut `integrity` (SHA-384) ajouté partout, avec les empreintes calculées depuis npm. Vérifié dans Chromium : le bon fichier se charge, un fichier falsifié est bloqué. |
| 11 | Pas d'installeur Windows (`install.sh` supposait macOS/Linux). | Ajout de `install.ps1`. |
| 12 | Chemin propre à l'auteur (`~/Developer/video-use`) dans `examples/captions/render-cmd.sh`. | Pointe vers le moteur fourni avec le plugin. |

## Utilisation dans l'app Claude

Dans l'app, les commandes s'exécutent dans un environnement Linux isolé, pas sur
votre PC, et personne n'y lance l'installeur. `RUNTIME-SETUP.md` indique à Claude
comment préparer chaque session : environnement Python créé depuis le fichier
verrouillé (empreintes vérifiées), HyperFrames 0.8.96 avec télémétrie coupée à
chaque commande, et Chromium de l'environnement pour le rendu.

**Clé ElevenLabs dans l'app** : aucune fenêtre de saisie masquée n'existe, donc la
clé doit être donnée dans la conversation, où elle reste dans l'historique.
Utilisez une **clé restreinte** : droits limités à la transcription et à la voix,
plafond de crédits, et révocation après usage. Claude la range dans
`~/.config/claude-video-editor/.env` avec des droits restreints, sans jamais la
réafficher. L'environnement étant éphémère, elle peut être redemandée à une
session suivante.

## Ce qui reste à votre charge (risques résiduels)

- **Confidentialité** : la transcription envoie l'**audio de vos vidéos** à ElevenLabs, et la voix off y envoie le **texte de vos scripts**. Claude a pour consigne de vous prévenir avant le premier envoi de chaque session. N'utilisez pas le plugin sur des rushs confidentiels si c'est un problème.
- **Dépendances de HyperFrames** : le paquet principal est figé, mais `npx` résout ses 122 sous-dépendances dans les plages déclarées (`^`). Un sous-paquet compromis publié demain pourrait donc être téléchargé. C'est le risque standard de tout outil npm. Pour l'éliminer, il faudrait installer HyperFrames depuis un lockfile, ce qui complique l'usage.
- **Modules installés à la première utilisation** : certaines commandes HyperFrames (TTS local, détourage, capture enrichie par Gemini) installent au premier usage `onnxruntime-node@1.21.1` ou `@google/genai@1.52.0` dans `~/.cache/hyperframes/optional`. Les versions sont exactes, mais `onnxruntime-node` télécharge un binaire natif pendant son installation. Le montage courant (coupe, sous-titres, rendu) n'en a pas besoin.
- **Chrome** : HyperFrames pilote Chrome sans interface pour le rendu. La capture de site web (`capture`) charge des pages tierces dans ce navigateur.
- **Mises à jour** : cette copie ne se met pas à jour toute seule. Pour intégrer une nouvelle version de l'auteur ou de HyperFrames, refaites un audit avant de changer la version figée.
- **Cet audit est une relecture de code**, pas une garantie : le code de HyperFrames lui-même (HeyGen) n'a pas été audité ligne par ligne, seulement son comportement réseau (télémétrie, mise à jour automatique, envois vers le cloud).

## Changer de version HyperFrames plus tard

1. Remplacer `0.8.96` partout (`grep -r 0.8.96`).
2. Vérifier l'arbre de dépendances : `npm install --package-lock-only hyperframes@X && npm audit`.
3. Tester lint et rendu sur `templates/animate-stills` et `examples/`.
