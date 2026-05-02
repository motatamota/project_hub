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
  gitlab/data/git-data/repositories \
  redmine/files redmine/plugins redmine/themes redmine/log

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

# Redmine: コンテナを GIT_UID で動かすため、書き込み対象を揃える
$SUDO chown -R "${GIT_UID}:${GIT_GID}" \
  redmine/files redmine/plugins redmine/themes redmine/log

# GitLab: git-data 配下を git ユーザ(${GIT_UID})に揃える
# コンテナ内 reconfigure で chgrp が走るので、事前に揃えておけば no-op になる
$SUDO chown -R "${GIT_UID}:${GIT_GID}" gitlab/data/git-data
$SUDO chmod 2770 gitlab/data/git-data/repositories

echo "Setup complete. UID/GID = ${GIT_UID}/${GIT_GID}"
