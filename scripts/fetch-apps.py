#!/usr/bin/env python3
"""Download official, pinned Android app releases from apps/manifest.json.

No alternate mirrors. Known SHA-256 checksums are verified before final rename.
The official Shizuku v13.6.0 release does not publish a GitHub asset digest;
that asset is identified by its upstream HTTPS URL and size and its measured
SHA-256 is reported. Run with Python >= 3.9 on a computer/server.
"""
import argparse
import hashlib
import json
import pathlib
import sys
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "apps" / "manifest.json"
PROFILES = {
    "manual": {"root-app", "kernelsu", "shizuku-official", "ashell-you"},
    "auto-shizuku": {"root-app", "kernelsu", "shizukuplus", "ashell-you"},
}
MAX_BYTES = 100 * 1024 * 1024


def measure(path):
    h = hashlib.sha256()
    n = 0
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            n += len(chunk)
            h.update(chunk)
    return n, h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--profile", choices=["manual", "auto-shizuku", "all"], default="manual")
    p.add_argument("--dest", type=pathlib.Path, default=ROOT / "dist" / "apps")
    p.add_argument("--verify-only", action="store_true")
    args = p.parse_args()
    apps = json.loads(MANIFEST.read_text(encoding="utf-8"))["apps"]
    desired = set(x["id"] for x in apps) if args.profile == "all" else PROFILES[args.profile]
    args.dest.mkdir(parents=True, exist_ok=True)
    failures = 0
    for app in apps:
        if app["id"] not in desired:
            continue
        name = app["filename"]
        if pathlib.PurePath(name).name != name or not name.lower().endswith(".apk"):
            raise ValueError("invalid filename in manifest")
        url = app["url"]
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != "github.com" or not parsed.path.startswith("/"):
            raise ValueError("download must use official GitHub HTTPS release")
        dest = args.dest / name
        expected_sha = app.get("sha256")
        expected_size = app.get("size_bytes")
        if dest.is_file():
            size, digest = measure(dest)
            if (expected_sha is None or digest == expected_sha) and (expected_size is None or size == expected_size):
                print(f"OK cached {name} {digest}" + (" (sha unknown upstream)" if expected_sha is None else ""))
                continue
        if args.verify_only:
            print(f"MISSING_OR_MISMATCH {name}", file=sys.stderr)
            failures += 1
            continue
        part = dest.with_name(dest.name + ".part")
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "honor-bsn-an00-root-recovery/1"}), timeout=40) as src, part.open("wb") as sink:
                total = 0
                h = hashlib.sha256()
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > MAX_BYTES:
                        raise ValueError("asset exceeds safety size threshold")
                    h.update(chunk)
                    sink.write(chunk)
            digest = h.hexdigest()
            if expected_sha is not None and digest != expected_sha:
                raise ValueError(f"SHA-256 mismatch {name}: {digest}")
            if expected_size is not None and total != expected_size:
                raise ValueError(f"size mismatch {name}: {total}")
            part.replace(dest)
            print(f"OK downloaded {name} sha256={digest}" + (" (upstream SHA unavailable)" if expected_sha is None else ""))
        except (OSError, ValueError) as exc:
            part.unlink(missing_ok=True)
            print(f"FAIL {name}: {exc}", file=sys.stderr)
            failures += 1
    if args.profile == "all":
        print("NOTE: stock Shizuku and Shizuku+ Drop-In are alternatives, do not install both together.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
