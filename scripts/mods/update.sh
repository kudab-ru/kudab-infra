#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[err] Это не git-репозиторий" >&2
  exit 2
fi

INFRA_BR="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$INFRA_BR" != "dev" && "$INFRA_BR" != "main" ]]; then
  echo "[err] Переключись на ветку dev или main в kudab-infra (сейчас: $INFRA_BR)" >&2
  exit 2
fi

TARGET="${TARGET:-$INFRA_BR}"   # можно переопределить: TARGET=dev|main make mods-update
VERBOSE="${VERBOSE:-0}"         # VERBOSE=1 make mods-update

if [[ "$TARGET" != "dev" && "$TARGET" != "main" ]]; then
  echo "[err] TARGET должен быть dev или main (сейчас: $TARGET)" >&2
  exit 2
fi

# Если infra "грязная" — допускаем только сдвиг gitlink в services/*
dirty="$(git status --porcelain)"
if [[ -n "$dirty" ]]; then
  if printf '%s\n' "$dirty" | grep -qvE '^[[:space:]]*[A-Z?]{1,2}[[:space:]]+services/'; then
    echo "[err] В kudab-infra есть незакоммиченные изменения (не только services/*)" >&2
    echo "$dirty" >&2
    echo >&2
    echo "Чтобы продолжить:" >&2
    echo "  1) git add -A && git commit -m \"infra: <что поменял>\" && git push" >&2
    echo "  2) или откатить: git restore --staged . && git restore ." >&2
    exit 2
  fi

  echo "[warn] В infra есть изменения (только services/*). Продолжаю — в конце зафиксирую gitlink-и, если они поменяются."
fi

# Ужесточаем SSH, чтобы не зависать и жить при дрожащей сети
: "${GIT_SSH_COMMAND:=ssh -o ConnectTimeout=10 -o ConnectionAttempts=3 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes}"
export GIT_SSH_COMMAND
export GIT_TERMINAL_PROMPT=0

# Подготовим подмодули (может временно поставить на pinned SHA — это нормально)
git submodule update --init --recursive

echo "== Подмодули: обновление до origin/$TARGET (ff-only) =="

git submodule foreach --recursive '
  set -euo pipefail

  BR="'"$TARGET"'"
  VERBOSE="'"$VERBOSE"'"

  svc="${name:-}"
  pth="${path:-}"
  if [[ -z "$svc" ]]; then
    if [[ -n "$pth" ]]; then svc="${pth##*/}"; else svc="unknown"; fi
  fi

  retry_quiet() {
    local max="${1:-5}"
    local sleep_s="${2:-2}"
    shift 2

    local tmp rc i
    tmp="$(mktemp)"

    i=1
    while [[ "$i" -le "$max" ]]; do
      : >"$tmp"
      if "$@" >/dev/null 2>"$tmp"; then
        rm -f "$tmp"
        return 0
      fi
      rc=$?

      if [[ "$VERBOSE" == "1" ]]; then
        echo "[dbg] $svc: попытка $i/$max провалилась (rc=$rc): $*" >&2
        sed -n "1,5p" "$tmp" >&2 || true
      fi

      if [[ "$i" -eq "$max" ]]; then
        echo "[err] $svc: не удалось выполнить после $max попыток: $*" >&2
        sed -n "1,120p" "$tmp" >&2 || true
        rm -f "$tmp"
        return "$rc"
      fi

      i=$((i+1))
      sleep "$sleep_s"
    done

    rm -f "$tmp"
    return 1
  }

  # Чистота подмодуля
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "[err] Грязный подмодуль: $svc (${pth:-?})" >&2
    git status --porcelain | sed -n "1,40p" >&2
    exit 2
  fi

  # Обновим origin/*
  retry_quiet 5 2 git fetch origin --prune

  # Переходим на ветку
  if git show-ref --verify --quiet "refs/heads/$BR"; then
    git switch "$BR" >/dev/null
  else
    if git show-ref --verify --quiet "refs/remotes/origin/$BR"; then
      git switch -c "$BR" "origin/$BR" >/dev/null
    else
      echo "[err] $svc: нет origin/$BR (ветка отсутствует на remote?)" >&2
      exit 2
    fi
  fi

  # Подтянуть ff-only
  retry_quiet 5 2 git pull --ff-only origin "$BR"

  echo "[ok] $svc -> $BR @ $(git rev-parse --short HEAD)"
'

echo "== infra: фиксация SHA подмодулей =="

git add services || true

if git diff --cached --quiet; then
  echo "[ok] Ссылки не изменились"
  exit 0
fi

git commit -m "infra: обновить ссылки подмодулей ($TARGET)"
git push
echo "[ok] Готово"
