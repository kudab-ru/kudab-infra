#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.."; pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[err] Это не git-репозиторий"
  exit 2
fi

# Цвета (если TTY)
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""
fi

INFRA_BR="$(git rev-parse --abbrev-ref HEAD)"
TARGET_BR="${TARGET:-$INFRA_BR}"   # можно переопределить: TARGET=dev make mods-status
FETCH="${FETCH:-0}"                # FETCH=1 make mods-status (обновит origin/*)

infra_dirty="$(git status --porcelain)"
infra_clean="✅ чисто"
if [[ -n "$infra_dirty" ]]; then
  infra_clean="⚠️ есть изменения"
fi

# список подмодулей из .gitmodules
mapfile -t SUB_PATHS < <(
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk '{print $2}' \
    | grep -E '^services/' \
    | sort
)

# Заголовок
printf "\n%s╭──────────────────────[ 🧩 ПОДМОДУЛИ / mods-status ]──────────────────────╮%s\n" "$C_CYAN$C_BOLD" "$C_RESET"
printf "  %sВетка infra:%s %s%s%s   |   %sСостояние:%s %s\n" "$C_BOLD" "$C_RESET" "$C_CYAN" "$INFRA_BR" "$C_RESET" "$C_BOLD" "$C_RESET" "$infra_clean"
printf "  %sЦелевая ветка сервисов:%s %s%s%s\n" "$C_BOLD" "$C_RESET" "$C_CYAN" "$TARGET_BR" "$C_RESET"
if [[ "$FETCH" == "1" ]]; then
  printf "  %sСеть:%s FETCH=1 (делаю git fetch origin --prune в каждом сервисе)\n" "$C_BOLD" "$C_RESET"
else
  printf "  %sСеть:%s FETCH=0 (сравнение с origin/%s по локальным refs)\n" "$C_BOLD" "$C_RESET" "$TARGET_BR"
fi
printf "%s╰──────────────────────────────────────────────────────────────────────────╯%s\n\n" "$C_CYAN$C_BOLD" "$C_RESET"

if [[ "${#SUB_PATHS[@]}" -eq 0 ]]; then
  echo "[warn] Не нашёл подмодулей в services/*"
  exit 0
fi

# Шапка таблицы
printf "%s%-24s %-12s %-10s %-10s %-9s %-6s %s%s\n" \
  "$C_BOLD" "Сервис" "Ветка" "HEAD" "PIN" "Δ" "dirty" "статус" "$C_RESET"
printf "%s\n" "-----------------------------------------------------------------------------------------"

problems=()
warn_count=0
err_count=0

for p in "${SUB_PATHS[@]}"; do
  svc="${p#services/}"

  if [[ ! -e "$p/.git" ]]; then
    printf "%-24s %-12s %-10s %-10s %-9s %-6s %s\n" \
      "$svc" "—" "—" "—" "—" "—" "${C_RED}❌ не инициализирован${C_RESET}"
    problems+=("❌ $svc: подмодуль не инициализирован (git submodule update --init --recursive)")
    ((err_count++)) || true
    continue
  fi

  # pinned SHA в infra (gitlink)
  pin_full="$(git ls-tree -d HEAD "$p" | awk '{print $3}' || true)"
  pin_short="${pin_full:0:8}"
  if [[ -z "$pin_full" ]]; then
    pin_short="—"
  fi

  head_full="$(git -C "$p" rev-parse HEAD 2>/dev/null || true)"
  head_short="${head_full:0:8}"

  branch="$(git -C "$p" symbolic-ref --short -q HEAD 2>/dev/null || true)"
  if [[ -z "$branch" ]]; then
    branch="DETACHED"
  fi

  dirty_n="$(git -C "$p" status --porcelain | wc -l | tr -d ' ')"

  # опционально: обновим refs
  if [[ "$FETCH" == "1" ]]; then
    # короткие ретраи на сетевые глюки
    ok=0
    for i in 1 2 3; do
      if git -C "$p" fetch origin --prune >/dev/null 2>&1; then ok=1; break; fi
      sleep 1
    done
    if [[ "$ok" != "1" ]]; then
      problems+=("⚠️ $svc: не удалось сделать fetch origin (сеть)")
      ((warn_count++)) || true
    fi
  fi

  # Δ (ahead/behind) относительно origin/TARGET_BR (если есть)
  delta="—"
  if git -C "$p" show-ref --quiet "refs/remotes/origin/$TARGET_BR"; then
    ab="$(git -C "$p" rev-list --left-right --count "origin/$TARGET_BR...HEAD" 2>/dev/null || echo "")"
    behind="$(awk '{print $1}' <<<"$ab")"
    ahead="$(awk '{print $2}' <<<"$ab")"
    behind="${behind:-0}"
    ahead="${ahead:-0}"
    delta="↓${behind} ↑${ahead}"
  else
    delta="нет origin/${TARGET_BR}"
  fi

  status_parts=()

  # проблемы/предупреждения
  if [[ "$branch" == "DETACHED" ]]; then
    status_parts+=("${C_YELLOW}⚠️ detached${C_RESET}")
    problems+=("⚠️ $svc: DETACHED (обычно лечится make mods-update)")
    ((warn_count++)) || true
  fi

  if [[ "$dirty_n" != "0" ]]; then
    status_parts+=("${C_YELLOW}⚠️ dirty${C_RESET}")
    problems+=("⚠️ $svc: есть незакоммиченные изменения внутри подмодуля ($dirty_n)")
    ((warn_count++)) || true
  fi

  if [[ -n "$pin_full" && "$head_full" != "$pin_full" ]]; then
    status_parts+=("${C_YELLOW}⚠️ ссылка≠HEAD${C_RESET}")
    problems+=("⚠️ $svc: ссылка infra (PIN=$pin_short) != HEAD ($head_short) — нужно зафиксировать gitlink (make mods-update или git add $p)")
    ((warn_count++)) || true
  fi

  # behind — это реально риск: ты локально отстаёшь от origin/ветки
  if [[ "$delta" =~ ^↓([0-9]+)\ ↑([0-9]+)$ ]]; then
    b="${BASH_REMATCH[1]}"
    a="${BASH_REMATCH[2]}"
    if [[ "$b" != "0" ]]; then
      status_parts+=("${C_RED}❌ behind${C_RESET}")
      problems+=("❌ $svc: отстаёт от origin/${TARGET_BR} на $b коммит(ов) — сделай pull (mods-update) или разберись почему")
      ((err_count++)) || true
    elif [[ "$a" != "0" ]]; then
      status_parts+=("${C_YELLOW}⚠️ ahead${C_RESET}")
      problems+=("⚠️ $svc: впереди origin/${TARGET_BR} на $a коммит(ов) — возможно не запушено")
      ((warn_count++)) || true
    fi
  fi

  if [[ "${#status_parts[@]}" -eq 0 ]]; then
    status_parts+=("${C_GREEN}✅ ok${C_RESET}")
  fi

  status_str="$(IFS=', '; echo "${status_parts[*]}")"

  printf "%-24s %-12s %-10s %-10s %-9s %-6s %s\n" \
    "$svc" "$branch" "$head_short" "$pin_short" "$delta" "$dirty_n" "$status_str"
done

printf "\n"

# Итоги
if [[ "$err_count" -eq 0 && "$warn_count" -eq 0 ]]; then
  printf "%s✅ Всё ровно.%s\n" "$C_GREEN$C_BOLD" "$C_RESET"
else
  printf "%sИтог:%s " "$C_BOLD" "$C_RESET"
  [[ "$err_count" -gt 0 ]] && printf "%s❌ ошибок: %d%s  " "$C_RED$C_BOLD" "$err_count" "$C_RESET"
  [[ "$warn_count" -gt 0 ]] && printf "%s⚠️ предупреждений: %d%s" "$C_YELLOW$C_BOLD" "$warn_count" "$C_RESET"
  printf "\n\n%sПроблемы:%s\n" "$C_BOLD" "$C_RESET"
  for m in "${problems[@]}"; do
    printf " - %s\n" "$m"
  done
fi

printf "\n%sПодсказки:%s\n" "$C_BOLD" "$C_RESET"
printf "  1) Привести сервисы к ветке %s:  %smake mods-update%s\n" "$TARGET_BR" "$C_CYAN" "$C_RESET"
printf "  2) Сравнить с актуальным origin:  %sFETCH=1 make mods-status%s\n" "$C_CYAN" "$C_RESET"
printf "  3) Продвинуть dev → main (ff-only): %smake mods-promote%s\n\n" "$C_CYAN" "$C_RESET"
