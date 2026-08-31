#!/bin/sh
# Rebuild the iOS staticlib + Xcode project, then re-apply the signing team.
#
# `ray bundle --ios` regenerates App.xcconfig (and the pbxproj) from scratch,
# dropping DEVELOPMENT_TEAM every time — so run this instead of `ray bundle --ios`
# directly and it re-injects the signing settings afterwards. See ROADMAP #9.
#
# Override the team with:  RAY_IOS_TEAM=XXXXXXXXXX raydesk-ios/rebuild.sh
set -e

TEAM="${RAY_IOS_TEAM:-A2CY27N22G}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$ROOT/raydesk-ios/App.xcconfig"

cd "$ROOT"
ray bundle --ios "$@"

if grep -q '^DEVELOPMENT_TEAM' "$CFG"; then
    echo "signing: DEVELOPMENT_TEAM already present in App.xcconfig"
else
    printf '\n// Re-applied by rebuild.sh (ray bundle --ios wipes these).\nCODE_SIGN_STYLE = Automatic\nDEVELOPMENT_TEAM = %s\n' "$TEAM" >> "$CFG"
    echo "signing: re-applied DEVELOPMENT_TEAM=$TEAM to App.xcconfig"
fi
