#!/usr/bin/env python3
"""Verify a SkillShortCuts CHAIN.jsonl audit chain.

No external dependencies. Usage:
  python3 script/verify_audit.py <run-dir>/CHAIN.jsonl --report
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


TERMINAL_EVENTS = {"WORKFLOW_SEALED", "WORKFLOW_ABORTED"}
INITIAL_HASH = "0" * 64


def canonical_value(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def canonical_entry(entry: dict[str, Any]) -> str:
    data = entry.get("data") or {}
    lines = [
        f"seq={entry.get('seq')}",
        f"timestamp={canonical_value(str(entry.get('timestamp', '')))}",
        f"event={canonical_value(str(entry.get('event', '')))}",
        f"ref={canonical_value(str(entry.get('ref') or ''))}",
        f"agent={canonical_value(str(entry.get('agent') or ''))}",
    ]
    for key in sorted(data.keys()):
        lines.append(f"data.{canonical_value(str(key))}={canonical_value(str(data[key]))}")
    lines.append(f"prev_hash={canonical_value(str(entry.get('prev_hash', '')))}")
    return "\n".join(lines)


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def read_entries(path: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise ValueError(f"Line {line_number}: invalid JSON: {exc}") from exc
    return entries


def verify_artifacts(base_dir: Path, entry: dict[str, Any]) -> list[str]:
    data = entry.get("data") or {}
    path_hash_pairs = {
        "artifact_path": "artifact_hash",
        "output_path": "output_hash",
        "current_path": "current_hash",
        "review_path": "review_hash",
    }
    errors: list[str] = []
    for path_key, hash_key in path_hash_pairs.items():
        rel_path = data.get(path_key)
        expected_hash = data.get(hash_key)
        if not rel_path or not expected_hash:
            continue
        artifact_path = (base_dir / rel_path).resolve()
        if not artifact_path.exists():
            errors.append(f"seq {entry.get('seq')}: missing artifact {rel_path}")
            continue
        actual_hash = sha256_file(artifact_path)
        if actual_hash != expected_hash:
            errors.append(
                f"seq {entry.get('seq')}: artifact hash mismatch for {rel_path}"
            )
    return errors


def verify(path: Path) -> tuple[bool, list[str], list[dict[str, Any]]]:
    if not path.exists():
        return False, [f"Audit chain not found: {path}"], []

    try:
        entries = read_entries(path)
    except ValueError as exc:
        return False, [str(exc)], []

    errors: list[str] = []
    if not entries:
        return False, ["Audit chain is empty."], entries

    if entries[0].get("event") != "GENESIS":
        errors.append("Missing GENESIS block at seq 0.")

    previous_hash = INITIAL_HASH
    for index, entry in enumerate(entries):
        if entry.get("seq") != index:
            errors.append(f"Sequence break: expected seq {index}, got {entry.get('seq')}.")

        if entry.get("prev_hash") != previous_hash:
            errors.append(f"prev_hash mismatch at seq {entry.get('seq')}.")

        expected_hash = sha256_text(canonical_entry(entry))
        if entry.get("entry_hash") != expected_hash:
            errors.append(f"entry_hash mismatch at seq {entry.get('seq')}.")

        if entry.get("event") in TERMINAL_EVENTS and index != len(entries) - 1:
            errors.append("Entries exist after terminal seal/abort event.")

        errors.extend(verify_artifacts(path.parent, entry))
        previous_hash = str(entry.get("entry_hash", ""))

    return not errors, errors, entries


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify SkillShortCuts CHAIN.jsonl")
    parser.add_argument("chain", type=Path, help="Path to CHAIN.jsonl")
    parser.add_argument("--report", action="store_true", help="Print human-readable report")
    parser.add_argument("--require-seal", action="store_true", help="Fail if chain is not sealed/aborted")
    args = parser.parse_args()

    ok, errors, entries = verify(args.chain)
    sealed = bool(entries and entries[-1].get("event") in TERMINAL_EVENTS)
    if args.require_seal and ok and not sealed:
        ok = False
        errors.append("Chain is valid but not sealed.")

    if args.report:
        print(f"File: {args.chain}")
        print(f"Entries: {len(entries)}")
        print(f"Status: {'VALID' if ok else 'INVALID'}")
        if entries:
            print(f"First event: {entries[0].get('event')}")
            print(f"Last event: {entries[-1].get('event')}")
            print(f"Final hash: {entries[-1].get('entry_hash')}")
            print(f"Sealed: {'yes' if sealed else 'no'}")
        if errors:
            print("\nFindings:")
            for error in errors:
                print(f"- {error}")

    if not args.report and errors:
        for error in errors:
            print(error, file=sys.stderr)

    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
