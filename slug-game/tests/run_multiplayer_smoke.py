"""Check gameplay, capacity, and full-room rejection using real ENet peers."""

import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot 4 executable")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    success = run_local_case(args.godot, project, "blood_smoke.gd", "BLOOD_SMOKE_PASS")
    success = run_local_case(args.godot, project, "shell_smoke.gd", "SHELL_SMOKE_PASS") and success
    success = run_case(args.godot, project, "multiplayer_smoke.gd", ("host", "client")) and success
    success = run_case(args.godot, project, "capacity_smoke.gd",
                       ("host", "first", "second", "overflow")) and success
    success = run_case(args.godot, project, "combat_smoke.gd", ("host", "client")) and success
    return 0 if success else 1


def run_local_case(godot, project, script, success_marker):
    result = subprocess.run(
        [godot, "--headless", "--path", str(project),
         "--script", f"res://tests/{script}"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15,
    )
    passed = result.returncode == 0 and success_marker in result.stdout
    passed = passed and "ERROR:" not in result.stdout and "WARNING:" not in result.stdout
    print(f"{script}: {'PASS' if passed else 'FAIL'}")
    if not passed:
        print(result.stdout[-14000:])
    return passed


def run_case(godot, project, script, roles):
    command = [godot, "--headless", "--path", str(project),
               "--script", f"res://tests/{script}"]
    with tempfile.TemporaryDirectory(prefix="slug-multiplayer-") as temporary:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as available_port:
            available_port.bind(("127.0.0.1", 0))
            test_port = available_port.getsockname()[1]
        environment = dict(os.environ, XDG_DATA_HOME=temporary, XDG_CONFIG_HOME=temporary,
                           SLUG_TEST_SYNC_DIR=temporary, SLUG_TEST_PORT=str(test_port))
        processes = []
        logs = []
        try:
            for role in roles:
                path = Path(temporary) / f"{role}.txt"
                log = path.open("w")
                logs.append((role, path, log))
                processes.append(subprocess.Popen(
                    command + ["--log-file", str(Path(temporary) / f"{role}.log"), "--", f"--{role}"],
                    stdout=log, stderr=subprocess.STDOUT, env=environment,
                ))
                if role == "host":
                    time.sleep(0.4)
            deadline = time.monotonic() + 35
            while any(process.poll() is None for process in processes):
                if time.monotonic() > deadline:
                    raise TimeoutError("Multiplayer smoke test exceeded 35 seconds")
                time.sleep(0.1)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
            for _, _, log in logs:
                log.close()
            success = len(processes) == len(roles)
            for (role, path, _), process in zip(logs, processes):
                output = path.read_text()
                passed = process.returncode == 0 and "MULTIPLAYER_SMOKE_PASS" in output
                passed = passed and "ERROR:" not in output and "WARNING:" not in output
                print(f"{script} {role}: {'PASS' if passed else 'FAIL'}")
                if not passed:
                    print(output[-14000:])
                success = success and passed
        return success


if __name__ == "__main__":
    raise SystemExit(main())
