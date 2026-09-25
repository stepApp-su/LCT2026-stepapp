#!/usr/bin/env bash
set -euo pipefail
: "${DEPLOY_HOST:?}" "${DEPLOY_PORT:?}" "${BUILD_NUMBER:?}" "${COMMIT_SHA:?}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ && "$COMMIT_SHA" =~ ^[0-9a-f]{40}$ ]]
[[ "$DEPLOY_PORT" =~ ^[0-9]+$ && "$DEPLOY_HOST" =~ ^[a-zA-Z0-9.-]+$ ]]
release_id="${BUILD_NUMBER}-${COMMIT_SHA}"
tag="build-${BUILD_NUMBER}"
(cd release && sha256sum -c SHA256SUMS)
if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" release/finni.apk release/stand.tar.gz release/SHA256SUMS \
    --target "$COMMIT_SHA" --title "Сборка ${BUILD_NUMBER}" --notes '' --draft
fi
remote="finni-deploy@${DEPLOY_HOST}"
ssh_opts=(-i "$HOME/.ssh/finni" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=20)
ssh "${ssh_opts[@]}" -p "$DEPLOY_PORT" "$remote" "mkdir -p /srv/finni/releases/$release_id"
scp "${ssh_opts[@]}" -P "$DEPLOY_PORT" release/stand.tar.gz "$remote:/srv/finni/releases/$release_id/stand.tar.gz"
ssh "${ssh_opts[@]}" -p "$DEPLOY_PORT" "$remote" "bash -s -- '$release_id'" < deploy/activate.sh
curl --fail --retry 3 --max-time 30 https://lct2026.stepapp.su/version.json | \
  python3 -c 'import json,os,sys; assert json.load(sys.stdin)["commit"] == os.environ["COMMIT_SHA"]'
curl --fail --head --max-time 30 https://lct2026.stepapp.su/downloads/finni.apk
gh release edit "$tag" --draft=false --latest
