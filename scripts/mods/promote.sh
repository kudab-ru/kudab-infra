#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

# infra должна быть чистой
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "[err] В kudab-infra есть незакоммиченные изменения" >&2
  exit 2
fi

git submodule update --init --recursive

echo "== Подмодули: promote dev -> main (ff-only) =="

git submodule foreach --recursive bash -lc '
  set -euo pipefail

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[err] Грязный подмодуль: $name ($path)" >&2
    exit 2
  fi

  git fetch origin --prune

  # актуализируем main
  if git show-ref --verify --quiet "refs/heads/main"; then
    git switch main >/dev/null
  else
    git switch -c main origin/main >/dev/null
  fi
  git pull --ff-only origin main >/dev/null

  # main <- dev только fast-forward
  git merge --ff-only origin/dev >/dev/null

  git push origin main >/dev/null
  echo "[ok] $name main <= dev @ $(git rev-parse --short HEAD)"
'

echo "== infra: обновляем main и фиксируем SHA =="
git switch main
git pull --ff-only
bash scripts/mods/update.sh
echo "[ok] Promote завершён"
