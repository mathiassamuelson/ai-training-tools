#!/usr/bin/env python3
"""
provenance.py — single source of truth for tool-repo git provenance.

THE INVARIANT (the reason this module exists): a result's provenance is the SHA of the
*tool* repo (rtx3090-ai-training-tools, "T") — the repo that holds the capture/judge/check
code and the eval inputs (prompts/probes/rubrics) that produced the result. It is NEVER the
SHA of the current working directory.

Post-split, the tools live in T but are run with cwd = R (rtx3090-ai-training) because
results are written into R. A cwd-based git read would therefore record R's SHA — pinning
the data repo instead of the code that produced the data, and re-introducing the very
dirty-by-sibling provenance friction the split was meant to remove. By anchoring to THIS
module's __file__ (which lives in T/tools/), every tool that imports it records T's SHA
regardless of where it is invoked from.

The returned keys (`tool_git_*`) name the fact honestly: this is the tool repo's state, and a
dirty flag here is the discipline gate that now matters — R being dirty at capture time is
expected and irrelevant to what produced the result.

Usage (sibling import; tools run as `python3 tools/<tool>.py`, so tools/ is sys.path[0]):

    from provenance import tool_provenance
    prov = tool_provenance()   # {"tool_git_sha": "...", "tool_git_dirty": False}
    out = {..., **prov}
"""

from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

# The tool repo root is wherever this file lives (T/tools/...). `git -C` walks up to the
# enclosing .git, so the exact subdir is immaterial — only that it is inside T, never cwd.
_TOOL_REPO_DIR = Path(__file__).resolve().parent


def _git(args: list[str]) -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(_TOOL_REPO_DIR), *args],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except Exception:  # noqa: BLE001 - provenance is best-effort; never fail a run over it
        return ""


def tool_provenance() -> dict[str, Any]:
    """Git SHA + dirty flag of the tool repo this module lives in (never cwd).

    Returns {"tool_git_sha": <sha|None>, "tool_git_dirty": <bool|None>}. Both are None if
    the tool repo has no HEAD yet (e.g. T freshly created with no initial commit) or git is
    otherwise unavailable — in which case commit T and re-run to get a real SHA.
    """
    sha = _git(["rev-parse", "HEAD"])
    if not sha:
        return {"tool_git_sha": None, "tool_git_dirty": None}
    return {"tool_git_sha": sha, "tool_git_dirty": bool(_git(["status", "--porcelain"]))}
