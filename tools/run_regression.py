"""Run offline Godot lifecycle tests with independent user data and bounded time."""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ISOLATED = {
    "hidden_lean_smoke": "hidden-lean-user",
    "relic_smoke": "relic-user",
    "chapter_three_smoke": "chapter-three-user",
    "liar_dice_smoke": "liar-dice-user",
    "build_routes_smoke": "build-routes-user",
    "road_events_smoke": "road-events-user",
    "main_menu_smoke": "main-menu-user",
    "expedition_save_smoke": "expedition-save-user",
    "expedition_save_ui_smoke": "expedition-ui-user",
    "expedition_restart_smoke": "expedition-restart-user",
    "profile_format_smoke": "profile-format-user",
    "profile_read_smoke": "profile-read-user",
    "sword_skills_save_smoke": "sword-skills-user",
    "finale_flow_smoke": "finale-save-user",
    "natural_relationship_smoke": "natural-relationship-user",
}


def run_case(name: str, engine: Path, run_dir: Path) -> dict:
    env = os.environ.copy()
    env["APPDATA"] = str(run_dir / ISOLATED.get(name, name + "-user"))
    # Linux/macOS 上 Godot 的 user:// 走 XDG_DATA_HOME，同样隔离，避免并行用例互相覆盖存档。
    env["XDG_DATA_HOME"] = env["APPDATA"]
    Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    command = [str(engine), "--headless", "--path", str(ROOT), "--script",
               "res://tools/" + name + ".gd", "--", "--cooperation-sim", "--offline-tests"]
    if name == "mobile_adaptation_smoke":
        command.append("--mobile-preview")
    started = time.monotonic()
    outputs = []
    environment_warnings = []
    try:
        cases = [command + ["--write-checkpoint"], command] if name == "expedition_restart_smoke" else [command]
        code = 0
        for case in cases:
            result = subprocess.run(case, cwd=ROOT, env=env, capture_output=True,
                                    text=True, encoding="utf-8", errors="replace", timeout=45)
            outputs.append(result.stdout + result.stderr)
            code = result.returncode
            if code:
                break
        output = "\n".join(outputs)
        # Some SceneTree tests report engine script errors but still exit with code 0.
        errors = [line for line in output.splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:"))]
        # Offline tests do not use TLS. Keep this Windows environment diagnostic
        # visible in the report without hiding any other engine or script errors.
        certificate_error = "ERROR: Failed to read the root certificate store."
        environment_warnings = sorted({line for line in errors if line == certificate_error})
        errors = [line for line in errors if line != certificate_error]
        if name == "expedition_save_smoke":
            errors = [line for line in errors if not line.startswith("ERROR: ConfigFile parse error")]
        passed = code == 0 and not errors
    except subprocess.TimeoutExpired as exc:
        output = "TIMEOUT (45s)\n" + str(exc.stdout or "") + str(exc.stderr or "")
        passed = False
        code = -1
    (run_dir / (name + ".log")).write_text(output, encoding="utf-8")
    return {"name": name, "passed": passed, "exit_code": code,
            "environment_warnings": environment_warnings,
            "seconds": round(time.monotonic() - started, 2), "log": str(run_dir / (name + ".log"))}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--only", nargs="*")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error("--godot must point to the Godot executable")
    names = sorted(p.stem for p in (ROOT / "tools").glob("*_smoke.gd")
                   if p.stem != "public_proxy_smoke")
    if args.only:
        unknown = set(args.only) - set(names)
        if unknown:
            parser.error("Unknown offline tests: " + ", ".join(sorted(unknown)))
        names = args.only
    run_dir = ROOT / ".godot" / "regression" / time.strftime("%Y%m%d-%H%M%S")
    run_dir.mkdir(parents=True, exist_ok=True)
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [pool.submit(run_case, name, args.godot.resolve(), run_dir) for name in names]
        for job in concurrent.futures.as_completed(jobs):
            result = job.result()
            results.append(result)
            print(("PASS " if result["passed"] else "FAIL ") + result["name"], flush=True)
    results.sort(key=lambda entry: entry["name"])
    (run_dir / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    failed = sum(not entry["passed"] for entry in results)
    warned = sum(bool(entry["environment_warnings"]) for entry in results)
    if warned:
        print(f"Environment warnings in {warned} cases; see results.json and original logs.", flush=True)
    print(f"{len(results) - failed}/{len(results)} passed; report: {run_dir}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
