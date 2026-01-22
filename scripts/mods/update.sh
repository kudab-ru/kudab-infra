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

TARGET="${TARGET:-$INFRA_BR}"   # TARGET=dev|main make mods-update
VERBOSE="${VERBOSE:-0}"         # VERBOSE=1 make mods-update

if [[ "$TARGET" != "dev" && "$TARGET" != "main" ]]; then
  echo "[err] TARGET должен быть dev или main (сейчас: $TARGET)" >&2
  exit 2
fi

# infra может быть "грязной" только из-за сдвинутых SHA подмодулей (services/*)
dirty="$(git status --porcelain)"
if [[ -n "$dirty" ]]; then
  if printf '%s\n' "$dirty" | grep -qvE '^[[:space:]]*[A-Z?]{1,2}[[:space:]]+services/'; then
    echo "[err] В kudab-infra есть незакоммиченные изменения (не только services/*)" >&2
    echo "$dirty" >&2
    echo >&2
    echo "Чтобы продолжить:" >&2
    echo '  1) git add -A && git commit -m "infra: <что поменял>" && git push' >&2
    echo "  2) или откатить: git restore --staged . && git restore ." >&2
    exit 2
  fi
  echo "[warn] В infra есть изменения (только services/*). В конце зафиксирую gitlink-и, если они поменяются."
fi

# Подготовим подмодули (может временно поставить на pinned SHA — это нормально)
git submodule update --init --recursive

# Ужесточаем SSH, чтобы не зависать и чуть лучше жить при дрожащей сети
: "${GIT_SSH_COMMAND:=ssh -o ConnectTimeout=10 -o ConnectionAttempts=3 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes}"
export GIT_SSH_COMMAND
export GIT_TERMINAL_PROMPT=0

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
      echo "[dbg] попытка $i/$max (rc=$rc): $*" >&2
      sed -n '1,20p' "$tmp" >&2 || true
    fi

    if [[ "$i" -eq "$max" ]]; then
      echo "[err] не удалось выполнить после $max попыток: $*" >&2
      sed -n '1,120p' "$tmp" >&2 || true
      rm -f "$tmp"
      return "$rc"
    fi

    i=$((i+1))
    sleep "$sleep_s"
  done

  rm -f "$tmp"
  return 1
}

# список подмодулей из .gitmodules
mapfile -t SUB_PATHS < <(
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk '{print $2}' \
    | grep -E '^services/' \
    | sort
)

if [[ "${#SUB_PATHS[@]}" -eq 0 ]]; then
  echo "[warn] Не нашёл подмодулей в services/*"
  exit 0
fi

echo "== Подмодули: обновление до origin/$TARGET (ff-only) =="

for p in "${SUB_PATHS[@]}"; do
  svc="${p#services/}"

  # если подмодуль есть в .gitmodules, но не инициализирован на диске
  if [[ ! -e "$p/.git" ]]; then
    echo "[warn] $svc: не инициализирован — пробую init"
    git submodule update --init --recursive "$p"
  fi

  if [[ ! -e "$p/.git" ]]; then
    echo "[err] $svc: подмодуль не инициализирован (нет $p/.git)" >&2
    exit 2
  fi

  # Чистота подмодуля
  if [[ -n "$(git -C "$p" status --porcelain)" ]]; then
    echo "[err] Грязный подмодуль: $svc ($p)" >&2
    git -C "$p" status --porcelain | sed -n '1,60p' >&2
    exit 2
  fi

  retry_quiet 5 2 git -C "$p" fetch origin --prune

  if ! git -C "$p" show-ref --verify --quiet "refs/remotes/origin/$TARGET"; then
    echo "[err] $svc: нет origin/$TARGET (ветка отсутствует на remote?)" >&2
    exit 2
  fi

  if git -C "$p" show-ref --verify --quiet "refs/heads/$TARGET"; then
    git -C "$p" switch "$TARGET" >/dev/null
  else
    git -C "$p" switch -c "$TARGET" "origin/$TARGET" >/dev/null
  fi

  retry_quiet 5 2 git -C "$p" pull --ff-only origin "$TARGET"

  echo "[ok] services/$svc -> $TARGET @ $(git -C "$p" rev-parse --short HEAD)"
done

echo "== infra: фиксация SHA подмодулей =="

git add services || true

if git diff --cached --quiet; then
  echo "[ok] Ссылки не изменились"
  exit 0
fi

git commit -m "infra: обновить ссылки подмодулей ($TARGET)"
git push
echo "[ok] Готово"
