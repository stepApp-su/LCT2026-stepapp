#!/usr/bin/env bash
set -euo pipefail
release_id="${1:?}"
[[ "$release_id" =~ ^[0-9]+-[0-9a-f]{40}$ ]]
target="/srv/finni/releases/$release_id"
test -d "$target"
cd "$target"
tar -xzf stand.tar.gz
test -s index.html && test -s main.dart.js && test -s downloads/finni.apk && test -s version.json
chmod -R u=rwX,go=rX "$target"
ln -sfn "$target" /srv/finni/current.next
mv -Tf /srv/finni/current.next /srv/finni/current
