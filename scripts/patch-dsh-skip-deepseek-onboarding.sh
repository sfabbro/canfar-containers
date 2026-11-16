#!/bin/bash
# Studio is keys-only: any provider key works (Settings → Keys). Upstream dsh
# still opens a mandatory-looking "Add an API key to get started" dialog that
# only accepts the official DeepSeek credential. Treat that readiness state as
# unavailable so onboarding auto-completes (same as "Configure later").
set -euo pipefail

root="${1:-/opt/astroai}"
target="$(find "${root}" -path '*/dsh-client-ui-settings-models/lib/client.js' 2>/dev/null | head -1 || true)"
if [[ -z "${target}" || ! -f "${target}" ]]; then
    echo "dsh-client-ui-settings-models client.js not found under ${root}" >&2
    exit 1
fi

python3 - "${target}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
# Idempotent: already patched.
if "astroai-keys-only" in text:
    print(f"already patched: {path}")
    raise SystemExit(0)
# dsh <= 0.2.1 ships this file readable; 0.2.2 ships it minified (backticks).
# onboardingReadiness is the only site of this exact return in either build.
forms = [
    ('return { kind: "credential-missing" };',
     'return { kind: "unavailable", reason: "astroai-keys-only" }; '
     '/* skip the DeepSeek-only first-run API key gate */'),
    ("return{kind:`credential-missing`}}",
     "return{kind:`unavailable`,reason:`astroai-keys-only`}}"),
]
for needle, replacement in forms:
    if text.count(needle) == 1:
        path.write_text(text.replace(needle, replacement, 1), encoding="utf-8")
        break
else:
    raise SystemExit(f"onboarding readiness needle not found (or not unique) in {path}")
print(f"patched DeepSeek onboarding skip: {path}")
PY
