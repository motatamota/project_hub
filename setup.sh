#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Load .env
if [ -f .env ]; then
  set -a; . ./.env; set +a
fi

GIT_UID="${GIT_UID:-998}"
GIT_GID="${GIT_GID:-998}"

mkdir -p \
  gitlab/config gitlab/logs gitlab/data \
  redmine/files redmine/plugins redmine/themes redmine/log redmine/sqlite

# Redmine が UID=${GIT_UID} で起動するため、書き込み対象ディレクトリの所有権を揃える
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

$SUDO chown -R "${GIT_UID}:${GIT_GID}" \
  redmine/files redmine/plugins redmine/themes redmine/log redmine/sqlite

echo "Setup complete. UID/GID = ${GIT_UID}/${GIT_GID}"
