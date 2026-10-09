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
    Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
    command = [str(engine), "--headless", "--path", str(ROOT), "--script",
               "res://tools/" + name + ".gd", "--", "--cooperation-sim", "--offline-tests"]
    started = time.monotonic()
    outputs = []
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
        if name == "expedition_save_smoke":
            errors = [line for line in errors if not line.startswith("ERROR: ConfigFile parse error")]
        passed = code == 0 and not errors
    except subprocess.TimeoutExpired as exc:
        output = "TIMEOUT (45s)\n" + str(exc.stdout or "") + str(exc.stderr or "")
        passed = False
        code = -1
    (run_dir / (name + ".log")).write_text(output, encoding="utf-8")
    return {"name": name, "passed": passed, "exit_code": code,
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
    print(f"{len(results) - failed}/{len(results)} passed; report: {run_dir}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
