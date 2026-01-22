#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

BR="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BR" != "dev" && "$BR" != "main" ]]; then
  echo "[err] Переключись на ветку dev или main в kudab-infra (сейчас: $BR)" >&2
  exit 2
fi

# infra может быть "грязной" только из-за сдвинутых SHA подмодулей (services/*)
dirty="$(git status --porcelain)"

# Если вообще чисто — ок, пропускаем
if [[ -n "$dirty" ]]; then
  # Разрешаем изменения ТОЛЬКО вида "M services/..."
  if printf '%s\n' "$dirty" | grep -qvE '^[[:space:]]*[A-Z?]{1,2}[[:space:]]+services/'; then
    echo "[err] В kudab-infra есть незакоммиченные изменения (не только services/*)" >&2
    printf '%s\n' "$dirty"
    exit 2
  fi
fi


git submodule update --init --recursive

echo "== Подмодули: обновление до origin/$BR (ff-only) =="

git submodule foreach --recursive '
  set -eu
  BR="'"$BR"'"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[err] Грязный подмодуль: ${name:-?} (${path:-?})" >&2
    exit 2
  fi

  git fetch origin --prune

  if git show-ref --verify --quiet "refs/heads/$BR"; then
    git switch "$BR" >/dev/null
  else
    git switch -c "$BR" "origin/$BR" >/dev/null
  fi

  git pull --ff-only origin "$BR" >/dev/null
  echo "[ok] ${name:-?} -> $BR @ $(git rev-parse --short HEAD)"
'

echo "== infra: фиксация SHA подмодулей =="
git add services || true

if git diff --cached --quiet; then
  echo "[ok] Ссылки не изменились"
  exit 0
fi

git commit -m "infra: обновить ссылки подмодулей ($BR)"
git push
echo "[ok] Готово"
