# CANFAR Studio

Contributed session image `images.canfar.net/astroai/studio:<tag>`: a coding
agent chat, a terminal and notebooks in one CANFAR session, behind one tab strip.

`improc-studio` and `specproc-studio` are the same image on `improc` or
`specproc`. There the science venv is the default Jupyter kernel and runs marimo.

## Tabs

| Tab | Process | Bind | Path | Starts |
|-----|---------|------|------|--------|
| Chat | `dsh --profile astroai` ([dsh](https://www.npmjs.com/package/@deepseek-ai/dsh)) | `127.0.0.1:3080` | `/` | at boot |
| Terminal | ghostty-web + tmux | `127.0.0.1:4793` | `/terminal/` | at boot |
| JupyterLab | `jupyter lab` | `127.0.0.1:8888` | `/jupyter/` | first open |
| marimo | `marimo edit <code folder>` | `127.0.0.1:2718` | `/marimo/` | first open |
| VS Code | OpenVSCode Server | `127.0.0.1:8080` | `/vscode/` | first open |
| ⚙ Settings | `canfar lab web` | `127.0.0.1:4792` | `/lab/` | at boot |

`studio-canfar-proxy.py` on `:5000` serves them all under
`/session/contrib/<id>`: it sends Skaha Connect to dsh's launch-token URL,
rewrites dsh's absolute URLs, splices WebSockets, streams Server-Sent Events,
adds the Settings bearer, and injects the tab strip (CANFAR logo, session
name). Tabs and routes live in `config/studio-tabs.json`; adding a tool is one
Dockerfile layer, one `_start_tool` case in `scripts/startup-studio.sh` and one
line there.

A tool that keeps crashing on start shows "could not start" with its log path
and a **Try again** link; background requests from an open tab never restart it.

## Settings tab

New users get a short checklist: an API key for Chat (DeepSeek is the
cheapest; OpenCode Zen, Gemini, OpenAI and Anthropic also work),
optional agents (Claude Code, Codex, Antigravity, OpenCode, Pi, Oh My Pi), the
code folder and automatic saves. Keys are kept in `~/.canfar/lab/.env` and in
dsh's `~/.dsh/.credentials.yaml`, synced both ways; dsh's own Settings → Models
edits the same keys.

Agents live on `$SCRATCH` and are reinstalled at the latest version when a
session starts. Code is in `$SCRATCH/src` by default (or a folder you pick);
Settings snapshots it to `/arc` and brings the latest snapshot back into an
empty scratch folder at the next start.

## dsh

Every image build installs the newest dsh release (highest semver across npm
dist-tags, `scripts/dsh-newest.sh`). Startup runs
`canfar-lab studio --prepare --profile canfar --no-install`, which sets up the
`astroai` dsh profile: CANFAR brand plugin, MCP tools, the review-panel preset,
a "Your code" workspace, and no telemetry export (`DSH_TELEMETRY_DISABLED=1`).
The image patches dsh so it does not force DeepSeek-only onboarding.

## State and logs

Per session, on scratch: `$SCRATCH/.dsh-$USER/` (`logs/`, `tool-state/`, pnpm
store, corepack, Jupyter runtime). Chat history follows the dsh state root on
scratch and is carried by Settings snapshots. Durable, in your home: `~/.dsh`
(profile, keys), `~/.canfar/lab` (keys, settings, snapshots), `~/.jupyter`,
`~/.openvscode-server` (VS Code settings and extensions).

## Build and test

```bash
make build-studio                 # resolves the newest dsh, then bakes
make test-studio-local            # Connect, tabs, onboarding, save/restore
python3 scripts/lib/test_studio_canfar_proxy.py
```

An unreleased canfar-lab: build a wheel into `../canfar-lab/dist`, then
`docker buildx bake studio --set studio.contexts.canfar-lab-dist=../canfar-lab/dist`.

## Launch

```bash
canfar create --name studio contributed images.canfar.net/astroai/studio:latest
```
