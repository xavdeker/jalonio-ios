#!/bin/bash
# SPDX-License-Identifier: EUPL-1.2
# Envoi de l'application vers TestFlight, par la CI macOS de GitHub (aucun Mac nécessaire).
#
#   ./deploy-ios.sh        lance le workflow « TestFlight » sur main et suit son déroulement
#
# La production n'est jamais atteinte directement : la version arrive sur TestFlight,
# on l'essaie, puis on la soumet à la vérification d'Apple dans App Store Connect.

set -euo pipefail

cd "$(dirname "$0")"

erreur() { echo "✗ $*" >&2; exit 1; }

[ -z "$(git status --porcelain)" ] || erreur "Modifications non commitées : TestFlight recevrait un code qui n'existe nulle part."
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || erreur "Branche main attendue."
git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || erreur "main n'est pas à jour avec GitHub (git push ou git pull)."
gh secret list --repo xavdeker/jalonio-ios | grep -q '^APP_STORE_CONNECT_KEY' \
    || erreur "Secret APP_STORE_CONNECT_KEY absent : gh secret set APP_STORE_CONNECT_KEY --repo xavdeker/jalonio-ios < ~/jalonio-keystore/AuthKey_VRMQN6YM7C.p8"

echo "→ Commit envoyé : $(git log --oneline -1)"
gh workflow run testflight.yml --repo xavdeker/jalonio-ios --ref main
sleep 5
run=$(gh run list --repo xavdeker/jalonio-ios --workflow testflight.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$run" --repo xavdeker/jalonio-ios --exit-status
echo "✓ Envoyé. Apple traite la version (10 à 30 minutes) avant qu'elle apparaisse dans TestFlight."
