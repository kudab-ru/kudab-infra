#!/usr/bin/env python3
"""
Хост-applier желаемого состояния VPN-прокси (задача 2b). Запускается systemd-
таймером как ROOT (см. deploy/proxy-applier.* ниже в PR). Замыкает петлю
"админка пишет БД → сервис применяет к xray" — без ручного sudo оператора.

Каждый тик:
  1. читает желаемое состояние из proxy_configs ЧЕРЕЗ контейнер (секрет не
     светится наружу): `docker exec kudab-api php artisan proxy:emit-state`;
  2. если enabled и apply_requested_at > applied_at → ПРИМЕНЯЕТ:
       - перегенерит /usr/local/etc/xray/config.json через gen-xray-balancer.py
         (mode=failover → пул подписки; mode=single → --only-index N),
       - `xray -test` (при провале — НЕ трогает live, пишет error),
       - бэкап → замена → `systemctl restart xray`,
       - probe Telegram через http://127.0.0.1:1081; при 000 → АВТО-ОТКАТ на
         бэкап + restart,
       - пишет статус+servers_cache обратно (artisan proxy:record-apply --applied);
  3. всегда (enabled) обновляет tg_probe для честного индикатора в UI.

Секрет подписки: получаем из emit-state (plaintext) → пишем в root-only файл в
/run (tmpfs, 0600) → отдаём генератору как --sub-file → удаляем. Не логируем URL.
"""
import json, os, re, subprocess, sys, tempfile, base64, importlib.util, time

XRAY_CONFIG = "/usr/local/etc/xray/config.json"
XRAY_API = "127.0.0.1:10085"
XRAY_BALANCER = "/usr/local/etc/xray/config.balancer.json"
XRAY_BACKUP = "/usr/local/etc/xray/config.json.bak-applier"
XRAY_BIN = "/usr/local/bin/xray"
HTTP_PROXY = "http://127.0.0.1:1081"
PROBE_URL = "https://api.telegram.org/"
GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen-xray-balancer.py")
API_CONTAINER = "kudab-api"


def log(msg):
    print(f"[proxy-applier] {msg}", flush=True)


def _load_gen():
    spec = importlib.util.spec_from_file_location("gen_xray_balancer", GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def emit_state():
    out = subprocess.run(
        ["docker", "exec", API_CONTAINER, "php", "artisan", "proxy:emit-state"],
        capture_output=True, text=True, timeout=60,
    )
    if out.returncode != 0:
        raise RuntimeError(f"emit-state failed: {out.stderr.strip()[:200]}")
    # берём последнюю непустую строку (artisan может подмешать баннер)
    line = [l for l in out.stdout.splitlines() if l.strip().startswith("{")][-1]
    return json.loads(line)


def record(payload, applied=False):
    b64 = base64.b64encode(json.dumps(payload).encode()).decode()
    cmd = ["docker", "exec", API_CONTAINER, "php", "artisan", "proxy:record-apply", f"--payload={b64}"]
    if applied:
        cmd.append("--applied")
    subprocess.run(cmd, capture_output=True, text=True, timeout=60)


def probe():
    try:
        r = subprocess.run(["curl", "-x", HTTP_PROXY, "-m", "10", "-o", "/dev/null",
                            "-s", "-w", "%{http_code}", PROBE_URL],
                           capture_output=True, text=True, timeout=15)
        return r.stdout.strip() or "000"
    except Exception:
        return "000"


def servers_cache(mod, sub_url):
    """Список серверов подписки для UI — БЕЗ секретов (id/pbk/sid не включаем)."""
    out = []
    for i, u in enumerate(mod.fetch_sub(sub_url)):
        try:
            p = mod.parse_vless(u)
            out.append({"index": i, "host": p["address"], "port": p["port"],
                        "name": p["name"], "security": p["security"], "network": p["network"]})
        except Exception:
            pass
    return out


def run_xray_test(path):
    r = subprocess.run([XRAY_BIN, "-test", "-config", path], capture_output=True, text=True, timeout=30)
    return r.returncode == 0 and "Configuration OK" in (r.stdout + r.stderr)


def balancer_status():
    """Через `xray api bi tg-bal`: (active_host, eligible_count, pool_size).
    Selects = ранжированные eligible-серверы балансера, #1 = активный. Маппим
    proxy-N → address из live-конфига. Возвращает (None,None,None) если api недоступен
    (напр. до первого applier-применения — в live-конфиге ещё нет api-inbound)."""
    try:
        r = subprocess.run([XRAY_BIN, "api", "bi", f"--server={XRAY_API}", "tg-bal"],
                           capture_output=True, text=True, timeout=10)
        selects = []
        in_selects = False
        for line in r.stdout.splitlines():
            if "Selects:" in line:
                in_selects = True
                continue
            if in_selects:
                m = re.search(r"\bproxy-\d+\b", line)
                if m:
                    selects.append(m.group(0))
        cfg = json.load(open(XRAY_CONFIG))
        tag2addr, pool = {}, 0
        for o in cfg.get("outbounds", []):
            t = o.get("tag", "")
            if t.startswith("proxy-"):
                pool += 1
                try:
                    tag2addr[t] = o["settings"]["vnext"][0]["address"]
                except Exception:
                    pass
        active = tag2addr.get(selects[0]) if selects else None
        return active, len(selects), pool
    except Exception:
        return None, None, None


def apply(state, mod):
    sub = state.get("subscription_url")
    if not sub:
        record({"ok": False, "message": "подписка не задана"})
        return
    mode = state.get("mode", "failover")
    idx = state.get("selected_server_index")

    # секрет → root-only tmpfile в /run, отдаём генератору, потом удаляем
    fd, subfile = tempfile.mkstemp(prefix="proxy-sub-", dir="/run")
    try:
        os.fchmod(fd, 0o600)
        os.write(fd, sub.encode())
        os.close(fd)

        gen_cmd = ["python3", GEN, "--sub-file", subfile, "--base", XRAY_CONFIG, "--out", XRAY_BALANCER]
        if mode == "single" and idx is not None:
            gen_cmd += ["--only-index", str(int(idx))]
        g = subprocess.run(gen_cmd, capture_output=True, text=True, timeout=90)
        if g.returncode != 0:
            record({"ok": False, "message": f"генерация не удалась: {g.stderr.strip()[:180]}"})
            return
    finally:
        try:
            os.unlink(subfile)
        except OSError:
            pass

    if not run_xray_test(XRAY_BALANCER):
        record({"ok": False, "message": "xray -test не прошёл — live не тронут"})
        return

    # бэкап → замена → рестарт
    subprocess.run(["cp", "-a", XRAY_CONFIG, XRAY_BACKUP], check=True)
    subprocess.run(["cp", XRAY_BALANCER, XRAY_CONFIG], check=True)
    subprocess.run(["systemctl", "restart", "xray"], check=False)
    time.sleep(4)

    code = probe()
    if code == "000":
        # авто-откат
        subprocess.run(["cp", XRAY_BACKUP, XRAY_CONFIG], check=False)
        subprocess.run(["systemctl", "restart", "xray"], check=False)
        record({"ok": False, "message": f"Telegram недоступен после применения (probe={code}) — откат на бэкап", "tg_probe": code})
        return

    cache = servers_cache(mod, sub)
    active_host, eligible, pool = balancer_status()
    active = active_host or ("balancer (auto-failover)" if mode == "failover" else f"single #{idx}")
    record({"ok": True, "message": "применено", "active_server": active,
            "eligible_count": eligible, "pool_size": pool,
            "tg_probe": code, "servers": cache}, applied=True)
    log(f"applied mode={mode} tg={code} servers={len(cache)} active={active} eligible={eligible}/{pool}")


def main():
    try:
        state = emit_state()
    except Exception as e:
        log(f"cannot read desired state: {e}")
        return 1

    if not state.get("enabled"):
        log("disabled — nothing to apply")
        return 0

    req, app = state.get("apply_requested_at"), state.get("applied_at")
    pending = req is not None and (app is None or app < req)

    mod = _load_gen()
    if pending:
        log("pending apply — applying")
        apply(state, mod)
    else:
        # только освежить индикатор Telegram + статус балансера в UI
        code = probe()
        active_host, eligible, pool = balancer_status()
        record({"ok": code != "000", "tg_probe": code, "active_server": active_host,
                "eligible_count": eligible, "pool_size": pool, "message": "health refresh"})
    return 0


if __name__ == "__main__":
    sys.exit(main())
