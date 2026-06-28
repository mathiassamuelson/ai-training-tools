#!/usr/bin/env bash
#
# run-judge.sh — thin wrapper around rca_quality_judge.py that loads the Anthropic
# API key from a file (default ~/.config/anthropic.key) into the environment, then
# execs the judge with all arguments forwarded verbatim (except -h/--help, which is
# intercepted to print THIS wrapper's usage — see below).
#
# Why a wrapper: a command run inside a script does NOT enter interactive shell
# history, so the key never appears in ~/.bash_history. The key is read here, never
# typed on a command line, never echoed, and never written to any file by this
# script. It is exported only into the judge's process (via exec) and dies with it.
#
# Post-split paths: the eval inputs (prompts/, probes/, rubrics/) ship in THIS tool repo,
# alongside the scripts — NOT in the data repo you run from. Reference an input by its path in
# the tool repo (absolute, or relative to it via "$(dirname "$0")/.."); --results-dir and the
# input result JSONs (--a/--b) live in the data repo.
#
# Usage (run from the data repo):
#   T="$(cd "$(dirname "$0")/.." && pwd)"   # this tool repo's checkout
#   ./tools/run-judge.sh --mode pairwise --a A.json --b B.json --judge-model <id> \
#       --reference-prompt "$T/prompts/operator-copilot-rca-system-prompt.md" \
#       --results-dir phase-3-optimization-and-quantization/week-14/results
#   ./tools/run-judge.sh ... --dry-run        # no key needed; prints prompts only
#   ANTHROPIC_KEY_FILE=/other/path ./tools/run-judge.sh ...   # override key location
#   ./tools/run-judge.sh --help               # this wrapper's usage; needs no key and no venv
#
# Help: `-h`/`--help` prints this header and exits 0 WITHOUT loading the key or invoking
# python. For the judge's own flag list, run `python3 rca_quality_judge.py --help` with the
# ai-inference venv active (the judge imports its deps at import time, so its --help needs the
# venv; this wrapper's --help does not).
#
# Key file setup (creates it owner-only, without the key entering history):
#   mkdir -p ~/.config && ( umask 077; cat > ~/.config/anthropic.key )
#   <paste the key, then press Enter and Ctrl-D>
#   chmod 600 ~/.config/anthropic.key   # if not already
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUDGE="$SCRIPT_DIR/rca_quality_judge.py"

# --help: print THIS wrapper's usage and exit, before any key-file logic or python exec.
# Kept ahead of everything so help never touches the key and works outside the venv.
usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; }
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      echo "For the full judge flag list: python3 \"$JUDGE\" --help  (needs the ai-inference venv active)."
      exit 0
      ;;
  esac
done

if [[ ! -f "$JUDGE" ]]; then
  echo "[error] judge not found next to wrapper: $JUDGE" >&2
  exit 2
fi

# --dry-run spends no tokens and needs no key; pass straight through.
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    exec python3 "$JUDGE" "$@"
  fi
done

KEYFILE="${ANTHROPIC_KEY_FILE:-$HOME/.config/anthropic.key}"

if [[ ! -f "$KEYFILE" ]]; then
  echo "[error] key file not found: $KEYFILE" >&2
  echo "        create it (no history exposure):" >&2
  echo "          mkdir -p \"\$(dirname \"$KEYFILE\")\" && ( umask 077; cat > \"$KEYFILE\" )" >&2
  echo "          <paste key, Enter, Ctrl-D>" >&2
  exit 2
fi

# Warn (don't fail) if the key file is readable beyond its owner.
perms="$(stat -c '%a' "$KEYFILE" 2>/dev/null || echo '')"
if [[ -n "$perms" && "$perms" != "600" && "$perms" != "400" ]]; then
  echo "[warn] $KEYFILE is mode $perms; tighten with: chmod 600 \"$KEYFILE\"" >&2
fi

# Command substitution strips the trailing newline; the value is never echoed.
ANTHROPIC_API_KEY="$(<"$KEYFILE")"
export ANTHROPIC_API_KEY

if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "[error] key file is empty: $KEYFILE" >&2
  exit 2
fi

exec python3 "$JUDGE" "$@"
