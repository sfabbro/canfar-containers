#!/usr/bin/env bash
# Install Ray into an existing venv from config/ray-deps.txt and stamp the version.
# Used by ray-base and ray-manager so both images share one pin.
set -euo pipefail

venv="${1:?venv path, e.g. /opt/astroai/venv/ray}"
deps="${2:?path to ray-deps.txt}"
py="${venv}/bin/python"
stamp="${3:-/opt/astroai/ray-version.txt}"

test -x "${py}"
test -f "${deps}"

# Exact pin line required (cluster ABI). Reject a floating "ray[default]".
# Use sed (not ${var#ray[default]==}) — bash treats […] as a character class.
want="$(sed -n 's/^ray\[default\]==\([0-9][^[:space:]]*\)$/\1/p' "${deps}" | head -1 || true)"
if [[ -z "${want}" ]]; then
    echo "ERROR: ${deps} must contain an exact pin like: ray[default]==2.60.0" >&2
    exit 1
fi

uv pip install --python "${venv}" -r "${deps}"
got="$("${py}" -c 'import ray; print(ray.__version__)')"
if [[ "${got}" != "${want}" ]]; then
    echo "ERROR: installed ray==${got} but ${deps} pins ${want}" >&2
    exit 1
fi
printf '%s\n' "${got}" >"${stamp}"
chmod a+r "${stamp}"
echo "ray ${got} → ${stamp}"
