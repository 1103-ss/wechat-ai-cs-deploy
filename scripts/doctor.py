# -*- coding: utf-8 -*-
"""
Environment doctor for WeChat AI Service.
Advisory checks only - never modifies the system.
Run:  python scripts/doctor.py
"""
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OK, WARN, FAIL = "PASS", "WARN", "FAIL"
results = []


def record(level, item, detail):
    results.append((level, item, detail))
    mark = {OK: "[PASS]", WARN: "[WARN]", FAIL: "[FAIL]"}[level]
    print(f"{mark} {item}: {detail}")


def check_python():
    v = sys.version_info
    if v >= (3, 10):
        record(OK, "Python", f"{v.major}.{v.minor}.{v.micro}")
    else:
        record(FAIL, "Python", f"{v.major}.{v.minor} - need 3.10+")


def check_pip_deps():
    # pip 包名 -> 实际 import 模块名（大多数同名，个别不同）
    import_name_map = {"pywin32": "win32api"}
    req = {}
    with open(os.path.join(ROOT, "requirements.txt"), encoding="utf-8") as f:
        for line in f:
            name = re.split(r"[<>= ]", line.strip())[0]
            if name:
                req[name.replace("-", "_").lower()] = name
    import importlib.util
    missing = []
    for mod, disp in req.items():
        # 优先映射表，其次把 requirements 里的规范名直接当模块名试
        candidates = [import_name_map.get(disp), mod, disp.replace("-", "_")]
        found = any(c and importlib.util.find_spec(c) is not None for c in candidates)
        if not found:
            missing.append(disp)
    if missing:
        record(FAIL, "Dependencies", "missing: " + ", ".join(missing)
               + "  -> run scripts\\install.bat")
    else:
        record(OK, "Dependencies", f"{len(req)} required packages importable")


def check_wxautox_auth():
    """Best-effort wxautox4 activation check via CLI."""
    py = sys.executable
    cmds = [[py, "-m", "wxautox4", "auth", "check"],
            [py, "-m", "wxauto4", "auth", "check"],
            ["wxautox4", "auth", "check"]]
    for cmd in cmds:
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        except Exception:
            continue
        text = (out.stdout or "") + (out.stderr or "")
        if not text.strip():
            continue
        m = re.search(r'"?active"?\s*[:=]\s*(true|false)', text, re.I)
        if m:
            active = m.group(1).lower() == "true"
            if active:
                record(OK, "wxautox4 license", "activated on this machine")
            else:
                record(FAIL, "wxautox4 license",
                       "not activated -> run: wxautox4 auth activate <CODE>")
            return
    record(WARN, "wxautox4 license",
           "could not query status; activate with: wxautox4 auth activate <CODE>")


def check_wechat_version():
    """Read Weixin display version from registry uninstall entries."""
    import winreg
    found = []
    roots = [(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
             (winreg.HKEY_LOCAL_MACHINE, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
             (winreg.HKEY_LOCAL_MACHINE,
              r"Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")]
    for root, path in roots:
        try:
            key = winreg.OpenKey(root, path)
        except OSError:
            continue
        i = 0
        while True:
            try:
                sub = winreg.EnumKey(key, i)
                i += 1
            except OSError:
                break
            try:
                sk = winreg.OpenKey(key, sub)
                name = winreg.QueryValueEx(sk, "DisplayName")[0]
                ver = winreg.QueryValueEx(sk, "DisplayVersion")[0]
            except OSError:
                continue
            if ("微信" in name or "Weixin" in name or "WeChat" in name) and ver:
                found.append(ver)
    if not found:
        record(WARN, "WeChat client", "not found in registry; log in to PC WeChat 4.1.x")
        return
    ver = sorted(found, reverse=True)[0]
    nums = tuple(int(x) for x in re.findall(r"\d+", ver)[:4])
    if nums >= (4, 1, 9) and nums <= (4, 1, 15, 13):
        record(OK, "WeChat client", f"{ver} (officially supported range)")
    elif nums == (4, 1, 8, 107):
        record(WARN, "WeChat client",
               f"{ver} - works for basic listening; advanced features may need 4.1.9+")
    elif nums < (4, 1, 9):
        record(WARN, "WeChat client", f"{ver} - upgrade to 4.1.9 ~ 4.1.15.13")
    else:
        record(WARN, "WeChat client",
               f"{ver} - newer than tested 4.1.15.13; check docs.wxauto.org")


def check_config():
    p = os.path.join(ROOT, "config", "config.json")
    if not os.path.exists(p):
        record(WARN, "config.json", "missing; copy config.example.json to config/config.json")
        return
    try:
        with open(p, encoding="utf-8") as f:
            cfg = json.load(f)
    except Exception as e:
        record(FAIL, "config.json", f"parse error: {e}")
        return
    keys = [c.get("key", "") for c in cfg.get("api_configs", [])]
    if any(keys):
        record(OK, "config.json", "at least one API key is set")
    else:
        record(WARN, "config.json", "no API key yet; set it in the web panel after start")
    groups = cfg.get("group", [])
    record(OK if groups else WARN, "Listen groups",
           ", ".join(groups) if groups else "none configured")


def check_single_instance():
    """Warn if another bot python is already running (Windows only)."""
    if not shutil.which("powershell"):
        return
    ps = ("$ErrorActionPreference='SilentlyContinue';"
          "Get-CimInstance Win32_Process | Where-Object { "
          "$_.Name -eq 'python.exe' -and $_.CommandLine -like '*web_server.py*' } | "
          "Measure-Object | Select-Object -ExpandProperty Count")
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                             capture_output=True, text=True, timeout=15).stdout.strip()
        n = int(out or "0")
        if n >= 1:
            record(WARN, "Running instances",
                   f"{n} panel process(es) already running")
    except Exception:
        pass


def main():
    print("=" * 56)
    print("  WeChat AI Service - environment doctor")
    print("=" * 56)
    check_python()
    check_pip_deps()
    check_wxautox_auth()
    check_wechat_version()
    check_config()
    check_single_instance()
    print("-" * 56)
    fails = [r for r in results if r[0] == FAIL]
    warns = [r for r in results if r[0] == WARN]
    print(f"Summary: {len(results) - len(fails) - len(warns)} pass, "
          f"{len(warns)} warn, {len(fails)} fail")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
