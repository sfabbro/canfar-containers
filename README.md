# AstroAI containers

Session images for astronomy and ML on the
[CANFAR Science Platform](https://www.opencadc.org/canfar/).
Images publish to Harbor as `images.canfar.net/astroai/<image>:<tag>`.

Licensed under [BSD-2-Clause](LICENSE).

```mermaid
flowchart TB
  subgraph astroai [AstroAI]
    Imgs["Harbor: images.canfar.net/astroai/*"]
    Lab["astroai workbench CLI"]
  end
  subgraph canfar [CANFAR]
    Portal[Science Portal]
    Skaha[Skaha / sessions /arc /scratch]
    CLI["canfar CLI"]
  end
  Portal --> Imgs
  CLI --> Skaha
  Imgs --> Skaha
  Lab --> Skaha
```

## Names at a glance

| Name | Meaning |
|------|---------|
| **AstroAI** | This product: GitHub [`astroai`](https://github.com/astroai), Harbor project `astroai`, images and tools |
| **CANFAR** | Hosting platform: portal, Skaha, auth, `/arc`, scheduling |
| **`canfar`** | Platform CLI — login, create/list/delete sessions |
| **`astroai`** | In-session CLI: project env, Ray cluster/jobs, agents |
| **`images.canfar.net/astroai/*`** | AstroAI images on CANFAR Harbor (host ≠ product name) |

## Sessions

| Image | Use for | Skaha type |
|-------|---------|------------|
| `base` | Headless parent (CI / batch) | — |
| `improc` | Astronomy FITS/HDF5 CLIs | Headless |
| `specproc` | Spectroscopy stack (pPXF and MOOG) | Headless |
| `openscience` | OpenScience research workspace | Contributed |
| `openresearch` | OpenResearch (`orx`) autoresearch dashboard | Contributed |
| `ray-worker` | Ray worker CPU or GPU (manager-launched) | Headless |
| `ray-manager` | Ray head + control panel + Dashboard ([RAY.md](docs/RAY.md)) | Contributed |
| `studio` | CANFAR Studio: chat agent, Terminal, JupyterLab, marimo, VS Code — [STUDIO.md](docs/STUDIO.md) | Contributed |
| `improc-studio` / `specproc-studio` | Same studio; science venv is default Python | Contributed |
| `terminal` / `notebook` | Ghostty web terminal / JupyterLab on base | Contributed / Notebook |
| `improc-terminal` / `improc-notebook` | Same on improc | Contributed / Notebook |
| `specproc-terminal` / `specproc-notebook` | Same on specproc | Contributed / Notebook |

Not in `make build-all` (still buildable): `marimo`, `vscode`.

## Documentation

| Doc | Audience |
|-----|----------|
| [docs/USAGE.md](docs/USAGE.md) | Session users — first session, storage, tools |
| [astroai USAGE](https://github.com/astroai/canfar-lab/blob/main/docs/USAGE.md) | `astroai` CLI detail |
| [docs/RAY.md](docs/RAY.md) | Ray clusters — manager + workers |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Developers — clone, build, test, PRs |
| [docs/OPERATORS.md](docs/OPERATORS.md) | Maintainers — push, register, smoke tests |

In-session: `canfar-lab help` · `less /opt/astroai/USAGE.md`

## Build and test

Requires Docker with buildx. Full loop: [CONTRIBUTING.md](docs/CONTRIBUTING.md).

```bash
make build-all              # default bake (DEFAULT_IMAGES)
make build-ray              # ray-manager + ray-worker
make build-improc           # improc family (+ base)
make build-specproc         # specproc family (+ base)
make build-studio           # one image (+ parents); also build/<name>
make test-local             # local smokes
make test-improc-local      # improc CLI smoke
make test-studio-local      # Studio Connect, tabs, onboarding, save/restore
make test-ray               # local Ray cluster + UI
```

## Push (maintainers)

See [OPERATORS.md](docs/OPERATORS.md). The `astroai` Harbor project is **public**
(anonymous pull); push still needs `docker login images.canfar.net`.

```bash
# TAG defaults to current UTC YY.MM; set BUILD_TAG to the same for release pushes
TAG=$(date -u +%y.%m)
make push-all TAG="$TAG" BUILD_TAG="$TAG"
```

Each push also publishes `:latest` (same digest as `TAG`).

## Layout

```
dockerfiles/   python (untagged bake parent) → base → sessions | improc | specproc; python → ray-base → worker; base → ray-manager
ray/           manager FastAPI app + worker helpers
scripts/       startup-*.sh, test-*.sh, profile
config/        canfar-lab.txt, ray-deps.txt, improc-py.txt, specproc-py.txt, notebooks (synced from lab)
docs/          USAGE, RAY, OPERATORS, CONTRIBUTING, STUDIO
examples/      improc + Ray smokes
```

## Design

- **Same images for CPU and GPU** — choose the node in the portal; CUDA/ML stacks via pixi/uv in the project.
- **Bake graph:** untagged `python` stage → fat `base` → `studio` / `terminal` / `notebook`, `openscience`, `openresearch`, `improc` → `improc-*`, `specproc` → `specproc-*`, and `ray-manager`. Slim `ray-base` (from that python stage, not published) → `ray-worker`. `marimo` and `vscode` are outside `build-all`. Python deps float at build from `config/*.txt` (latest PyPI `canfar-lab`; optional local wheel via bake `canfar-lab-dist` for `studio`).
- **One Python:** `PYTHON_VERSION` (default `3.13`) is shared by `base`, `ray-worker`, `ray-manager`, `improc`, and `specproc`. uv is forbidden from downloading a second interpreter (`UV_PYTHON_DOWNLOADS=never`); science/Ray venvs use `uv venv --python python3` and `assert-image-python`.
- **Fast session disks:** `WORK` is `$SCRATCH/src` when `/srcdir` is the container overlay (OOM-fragile) and `/scratch` is a volume; `SCRATCH` (`/scratch`) holds data and caches. Both are session-private. `/arc/home` and `/arc/projects` are shared across sessions. Persist with `canfar-lab save` / `git push`.
- **Skaha types:** Contributed listen on **5000**; Notebook on **8888**.
- **Auth at the edge:** Session UIs trust CANFAR TLS + portal login. Use these images only behind an authenticating reverse proxy.

Heavy site software: [CVMFS on CANFAR](https://github.com/opencadc/canfar/blob/main/docs/platform/cvmfs.md).

## Related repos

| Repo | Role |
|------|------|
| [astroai/canfar-lab](https://github.com/astroai/canfar-lab) | In-session CLI (`astroai`) |
| [opencadc/canfar](https://github.com/opencadc/canfar) | Platform client |
| [opencadc/science-platform](https://github.com/opencadc/science-platform) | Skaha / Helm (platform team) |

## Contributing

Pull requests welcome — [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).
