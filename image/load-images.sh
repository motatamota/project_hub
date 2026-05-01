#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

shopt -s nullglob
tars=( *.tar )

if [ ${#tars[@]} -eq 0 ]; then
  echo "No .tar files found in $(pwd)"
  exit 1
fi

for tar in "${tars[@]}"; do
  echo "==> docker load -i $tar"
  docker load -i "$tar"
done

echo "All images loaded."
docker images
