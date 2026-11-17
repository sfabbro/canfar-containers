# AGENTS.md

Operating guidance for coding agents and maintainers working in `astroai/canfar-containers`.

## Mission

`canfar-containers` builds and maintains session and platform container images for astronomy and machine learning on the [CANFAR Science Platform](https://www.opencadc.org/canfar/). Images are published to Harbor under `images.canfar.net/astroai/<image>:<tag>`.

## Stack and Architecture

- **Bake Graph (`docker-bake.hcl`):**
  - Untagged `python` stage (Python 3.13 + uv/pixi foundation). `PYTHON_VERSION` (Make/bake, default `3.13`) is the single shared CPython for `base`, `ray-worker`, `ray-manager`, `improc`, and `specproc` — one ABI, no uv-managed second interpreter (`UV_PYTHON_DOWNLOADS=never`).
  - `make build-all` publishes `base`, `improc`, `specproc`, `openscience`, `openresearch`, `ray-worker`, `ray-manager`, studios `studio` / `improc-studio` / `specproc-studio`, plus `terminal`. Per image: `make build-<name>` (also `build/<name>`). `marimo`, `vscode`, `notebook`, and `improc-` / `specproc-` `terminal` / `notebook` are buildable and not in that group (Studio covers them).
  - `studio` is the studio Dockerfile on `base`. `improc-studio` and `specproc-studio` reuse that Dockerfile with `improc` or `specproc` as the parent, and that science venv is the default Jupyter kernel and the marimo interpreter.
  - Slim `ray-base` (not a Harbor image) → `ray-worker`; fat `base` → `ray-manager`. Both Ray images are in `build-all`.
- **Ray Stack (`ray/`):**
  - FastAPI-based Ray cluster manager app (`ray/manager/`) and worker lifecycle helpers (`ray/worker/`).
  - **Cluster ABI:** manager and worker use the same `PYTHON_VERSION` and the exact `ray[default]==…` pin in `config/ray-deps.txt` (Ray requires matching Ray + Python on every node). Other deps still float; bump the Ray pin and `make build-ray` together.
- **In-Session Integrations:**
  - `astroai` CLI and lab utilities: `config/canfar-lab.txt` (unpinned); images resolve the latest `canfar-lab` from PyPI at build (Studio images take a wheel from `../canfar-lab/dist` when there is one).
  - Writable CADC environment (`/opt/canfar`).
- **No package lockfiles:** Python deps float at image build from `config/*.txt` (same model as improc/specproc), except the deliberate Ray pin above.

## Verification Commands and Tiers

### 1. Fast Static & Host Tests (Docker-Free — Pre-Push Gate)

Run these before any commit or push. They require no Docker daemon:

```bash
make lint
```

This runs:
- `make lint-doc-quota`: Verifies doc assertions.
- `make test-host`: Docker-free host self-checks (peek/osc52, agent-wizard unit tests, Starship prompt configuration).

Ray manager unit tests:
```bash
(cd ray/manager && uv sync --group dev && uv run ruff check . && uv run pytest tests/ -q)
```

### 2. Docker Local Smokes

Requires Docker with buildx:

```bash
make build-all BUILD_TAG=local
make test-local           # local smoke test on all session images
make test-improc-local    # verify astronomy improc CLIs
make test-studio-local    # Studio Connect + tabs (build-studio first; optional local canfar-lab wheel)
make test-ray SMOKE=1     # fast Ray container & UI smoke
```

## Agent PR Hygiene and Rules

1. **Agent-Neutral Instructions:** All agents (Antigravity, Cursor, Codex, Claude, OpenCode, Pi) use this `AGENTS.md` as the single canonical repository guide. Do not create agent-specific instruction duplicates.
2. **Float at build:** Do not reintroduce committed Python lockfiles (`*.lock` under `config/` for pip, or `ray/manager/uv.lock`). The container `TAG` is the user-facing pin.
3. **No Secrets / Local Tags:** Never commit API keys, `.env` files, or production Harbor credentials.
4. **Minimal Diffs:** Batch mechanical refactors and avoid noisy whitespace or formatting-only changes across unrelated files.
5. **Follow `~/src/AGENTS.md`:** Ship changes via GitHub pull requests against `astroai/canfar-containers`.

## Env hygiene

- Prefer `pixi run` / `pixi run python` over bare `python3` when Pixi exists.
- Never `pip install --user` or install into `~/.local` / `$HOME/.local` (esp. CANFAR `/arc/home`).
- Headless/batch: `export PYTHONNOUSERSITE=1` and `unset PYTHONPATH`.
- Publish/launch under `images.canfar.net/astroai/*` — **never** recommend `skaha/*` for AstroAI sessions.
- On CANFAR: read skill `canfar-lab-workflow` (mounts, quotas, resources, headless, ports).
