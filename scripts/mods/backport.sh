#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[err] Это не git-репозиторий" >&2
  exit 2
fi

# infra должна быть чистой (разрешаем "грязь" только services/* — как в promote/update)
dirty="$(git status --porcelain)"
if [[ -n "$dirty" ]]; then
  if printf '%s\n' "$dirty" | grep -qvE '^[[:space:]]*[A-Z?]{1,2}[[:space:]]+services/'; then
    echo "[err] В kudab-infra есть незакоммиченные изменения (не только services/*)" >&2
    printf '%s\n' "$dirty" >&2
    exit 2
  fi
  echo "[warn] В infra есть изменения (только services/*). Это ок — в конце зафиксирую gitlink-и."
fi

INFRA_BR="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$INFRA_BR" != "dev" && "$INFRA_BR" != "main" ]]; then
  echo "[err] Переключись на ветку dev или main в kudab-infra (сейчас: $INFRA_BR)" >&2
  exit 2
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

echo "== Подмодули: backport main -> dev (ff-only) =="

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
    git -C "$p" status --porcelain | sed -n '1,80p' >&2
    exit 2
  fi

  retry_quiet 5 2 git -C "$p" fetch origin --prune

  if ! git -C "$p" show-ref --verify --quiet "refs/remotes/origin/main"; then
    echo "[err] $svc: нет origin/main (ветка отсутствует на remote?)" >&2
    exit 2
  fi
  if ! git -C "$p" show-ref --verify --quiet "refs/remotes/origin/dev"; then
    echo "[err] $svc: нет origin/dev (ветка отсутствует на remote?)" >&2
    exit 2
  fi

  # main: обновить до origin/main
  if git -C "$p" show-ref --verify --quiet "refs/heads/main"; then
    git -C "$p" switch main >/dev/null
  else
    git -C "$p" switch -c main origin/main >/dev/null
  fi
  retry_quiet 5 2 git -C "$p" pull --ff-only origin main >/dev/null

  # dev: обновить до origin/dev, затем ff-only до main
  if git -C "$p" show-ref --verify --quiet "refs/heads/dev"; then
    git -C "$p" switch dev >/dev/null
  else
    git -C "$p" switch -c dev origin/dev >/dev/null
  fi
  retry_quiet 5 2 git -C "$p" pull --ff-only origin dev >/dev/null

  # dev <= main (ff-only)
  git -C "$p" merge --ff-only main >/dev/null

  # push dev
  retry_quiet 5 2 git -C "$p" push origin dev >/dev/null

  echo "[ok] services/$svc dev <= main @ $(git -C "$p" rev-parse --short HEAD)"
done

echo "== infra: обновляем dev и фиксируем SHA (gitlink) =="

# Обновим infra/dev, чтобы он указывал на новые SHA dev-веток
if git show-ref --verify --quiet refs/heads/dev; then
  git switch dev >/dev/null
else
  git switch -c dev origin/dev >/dev/null
fi
retry_quiet 5 2 git pull --ff-only origin dev >/dev/null

# update.sh сам:
# - приведёт каждый сервис к origin/dev (ff-only)
# - зафиксирует обновлённые gitlink-и в infra/dev и запушит
bash scripts/mods/update.sh

# Вернёмся на исходную ветку infra
git switch "$INFRA_BR" >/dev/null

echo "[ok] Backport завершён (main -> dev + infra/dev обновлён)"
