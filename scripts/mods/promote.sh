#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

# infra должна быть чистой (кроме services/* тут лучше не позволять ничего)
dirty="$(git status --porcelain)"
if [[ -n "$dirty" ]]; then
  if printf '%s\n' "$dirty" | grep -qvE '^[[:space:]]*[A-Z?]{1,2}[[:space:]]+services/'; then
    echo "[err] В kudab-infra есть незакоммиченные изменения (не только services/*)" >&2
    printf '%s\n' "$dirty"
    exit 2
  fi
fi

git submodule update --init --recursive

export GIT_SSH_COMMAND='ssh -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes'

echo "== Подмодули: promote dev -> main (ff-only) =="

git submodule foreach --recursive '
  set -eu

  retry() {
    max="${1:-5}"
    sleep_s="${2:-2}"
    shift 2
    n=0
    while ! "$@"; do
      n=$((n+1))
      if [ "$n" -ge "$max" ]; then return 1; fi
      sleep "$sleep_s"
    done
  }

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[err] Грязный подмодуль: ${name:-?} (${path:-?})" >&2
    exit 2
  fi

  retry 5 2 git fetch origin --prune

  if git show-ref --verify --quiet "refs/heads/main"; then
    git switch main >/dev/null
  else
    git switch -c main origin/main >/dev/null
  fi
  retry 5 2 git pull --ff-only origin main >/dev/null

  git merge --ff-only origin/dev >/dev/null

  retry 5 2 git push origin main >/dev/null
  echo "[ok] ${name:-?} main <= dev @ $(git rev-parse --short HEAD)"
'

echo "== infra: обновляем main и фиксируем SHA =="
git switch main
git pull --ff-only
bash scripts/mods/update.sh
echo "[ok] Promote завершён"
