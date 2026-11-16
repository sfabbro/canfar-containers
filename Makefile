# AstroAI session / platform images → images.canfar.net/astroai/<name>:<tag>
#
# Per container:  make build-<name>   or   make build/<name>
# Families:       make build-all | build-ray | build-improc | build-specproc
# dsh is buildable but not in build-all until verified on CANFAR.

SHELL := bash
OWNER ?= astroai
REGISTRY ?= images.canfar.net
TAG ?= $(shell date -u +%y.%m)
BUILD_TAG ?= local
PYTHON_VERSION ?= 3.13

export OWNER REGISTRY PYTHON_VERSION

IMAGE_PREFIX := $(REGISTRY)/$(OWNER)

# --load lands tags in the local docker daemon (required for test-local /
# test-agent-local). Without it, a docker-container buildx driver only caches.
BAKE_FLAGS ?= --load

# ---------------------------------------------------------------------------
# Image lists (single source of truth for Make; keep in sync with docker-bake.hcl)
# ---------------------------------------------------------------------------

# bake group "default" / "release" — make build-all and make push-all
DEFAULT_IMAGES := \
	base improc specproc openscience openresearch \
	ray-worker ray-manager \
	studio improc-studio specproc-studio \
	terminal notebook \
	improc-terminal improc-notebook \
	specproc-terminal specproc-notebook

# Buildable Harbor images not in build-all (bake targets exist)
EXTRA_IMAGES := dsh marimo vscode

ALL_IMAGES := $(DEFAULT_IMAGES) $(EXTRA_IMAGES)

SESSION_IMAGES := $(DEFAULT_IMAGES)
RAY_IMAGES := ray-manager ray-worker
IMPROC_IMAGES := improc improc-studio improc-terminal improc-notebook
SPECPROC_IMAGES := specproc specproc-studio specproc-terminal specproc-notebook

# bake parents only — never push to Harbor
INTERNAL_IMAGES := python ray-base

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

.PHONY: help
help:
	@echo "AstroAI session images (CANFAR Harbor: images.canfar.net/astroai)"
	@echo "========================="
	@echo "Build"
	@echo "  make build-all              default bake group (see DEFAULT_IMAGES)"
	@echo "  make build-ray              ray-manager + ray-worker"
	@echo "  make build-improc           improc family (+ base via bake)"
	@echo "  make build-specproc         specproc family (+ base via bake)"
	@echo "  make build-<name>           one image (+ parents); also build/<name>"
	@echo "  make build-dsh              astroai/dsh (not in build-all yet)"
	@echo "  make build/improc           single improc image (build-improc = family)"
	@echo ""
	@echo "  Images: $(ALL_IMAGES)"
	@echo ""
	@echo "Push / release"
	@echo "  make push-all | push-ray | push-improc | push-specproc"
	@echo "  make push-<name>            retag BUILD_TAG → TAG + :latest and push"
	@echo "  make release-push           bake+push default group (no local load)"
	@echo "  make release-push-ray | release-push-improc | release-push-specproc"
	@echo ""
	@echo "Test"
	@echo "  make test-local             verify DEFAULT_IMAGES locally"
	@echo "  make test-studio-local      Studio stamp+dangling .dsh → token → 200"
	@echo "  make test-dsh-local         dsh: Connect, Agent + Lab tabs, onboarding"
	@echo "  make test-improc-local | test-specproc-local | test-base-local"
	@echo "  make test-agent-local       agent command matrix (all session images)"
	@echo "  make test-ray [SMOKE=1]     Ray container + local cluster + UI"
	@echo "  make test-canfar | test-canfar-agents | test-canfar-session"
	@echo "  make test-canfar-ray | test-canfar-ray-gpu | test-canfar-ray-autoscale"
	@echo "  make test-host              docker-free host self-checks"
	@echo ""
	@echo "Lint / sync"
	@echo "  make lint                   lint-doc-quota + desk-assets + test-host"
	@echo "  make sync-marimo-starter | sync-notebook-starters | sync-desk-assets"
	@echo "  make desk-assets-check | lint-doc-quota"
	@echo ""
	@echo "  make clean | clean-all"
	@echo "  make harbor-cleanup       DRY_RUN=1 preview; omit DRY_RUN to delete stale Harbor tags"
	@echo "  OWNER=$(OWNER)  REGISTRY=$(REGISTRY)  BUILD_TAG=$(BUILD_TAG)  TAG=$(TAG)"

# ---------------------------------------------------------------------------
# Sync (starters / desk assets from sibling canfar-lab)
# ---------------------------------------------------------------------------

ASTROAI_LAB_DIR ?= $(shell test -d ../canfar-lab && echo ../canfar-lab || echo ../astroai-lab)
ASTROAI_LAB_STARTER ?= $(ASTROAI_LAB_DIR)/src/canfar_lab/data/notebooks/starter.py
ASTROAI_LAB_IPYNB ?= $(ASTROAI_LAB_DIR)/src/canfar_lab/data/notebooks/starter.ipynb
ASTROAI_LAB_RAY_NB ?= $(ASTROAI_LAB_DIR)/src/canfar_lab/data/notebooks/ray_train.ipynb

.PHONY: sync-marimo-starter sync-notebook-starters sync-desk-assets desk-assets-check
sync-marimo-starter: ## copy marimo starter.py from sibling astroai-lab checkout
	@test -f "$(ASTROAI_LAB_STARTER)" || { echo "missing $(ASTROAI_LAB_STARTER)"; exit 1; }
	cp "$(ASTROAI_LAB_STARTER)" config/notebooks/starter.py
	@echo "updated config/notebooks/starter.py from $(ASTROAI_LAB_STARTER)"

sync-notebook-starters: sync-marimo-starter ## copy all lab notebooks into config/notebooks
	@test -f "$(ASTROAI_LAB_IPYNB)" || { echo "missing $(ASTROAI_LAB_IPYNB)"; exit 1; }
	@test -f "$(ASTROAI_LAB_RAY_NB)" || { echo "missing $(ASTROAI_LAB_RAY_NB)"; exit 1; }
	cp "$(ASTROAI_LAB_IPYNB)" config/notebooks/starter.ipynb
	cp "$(ASTROAI_LAB_RAY_NB)" config/notebooks/ray_train.ipynb
	@echo "updated config/notebooks/{starter.ipynb,ray_train.ipynb}"

sync-desk-assets: ## vendor the Desk dock from sibling canfar-lab + refresh the lock
	@chmod +x scripts/sync-desk-assets.sh
	@./scripts/sync-desk-assets.sh

desk-assets-check: ## fail if the vendored Desk dock drifts from config/desk-assets.lock
	@chmod +x scripts/sync-desk-assets.sh
	@./scripts/sync-desk-assets.sh --check

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

.PHONY: build-all build-ray build-improc build-specproc

build-all: ## build session images into local docker
	TAG=$(BUILD_TAG) docker buildx bake $(BAKE_FLAGS)

build-ray: ## build Ray manager + worker (uses same base TAG)
	TAG=$(BUILD_TAG) docker buildx bake $(BAKE_FLAGS) ray-manager ray-worker

# Family aggregators. Single-image builds for these names: make build/improc etc.
build-improc: ## build improc family (+ base)
	TAG=$(BUILD_TAG) docker buildx bake $(BAKE_FLAGS) $(IMPROC_IMAGES)

build-specproc: ## build specproc family (+ base)
	TAG=$(BUILD_TAG) docker buildx bake $(BAKE_FLAGS) $(SPECPROC_IMAGES)

# Per-container targets. Hyphen form skips improc/specproc (family names above).
# Slash form covers every bake target, including internals and improc/specproc singles.
HYPHEN_BUILD_IMAGES := $(filter-out improc specproc,$(ALL_IMAGES))

# The dsh image takes the newest dsh release on every build (no pin). Resolving
# it here gives bake an exact version, so a cached layer is reused only while
# that version is still the newest. `make build-dsh DSH_VERSION=x.y.z` builds a
# given one; with npm unreachable the build resolves it itself ("newest").
build-dsh build/dsh: export DSH_VERSION ?= $(shell ./scripts/dsh-newest.sh 2>/dev/null || echo newest)

define BUILD_HYPHEN
.PHONY: build-$(1)
build-$(1):
	TAG=$$(BUILD_TAG) docker buildx bake $$(BAKE_FLAGS) $(1)
endef
$(foreach img,$(HYPHEN_BUILD_IMAGES),$(eval $(call BUILD_HYPHEN,$(img))))

define BUILD_SLASH
.PHONY: build/$(1)
build/$(1):
	TAG=$$(BUILD_TAG) docker buildx bake $$(BAKE_FLAGS) $(1)
endef
$(foreach img,$(ALL_IMAGES) $(INTERNAL_IMAGES),$(eval $(call BUILD_SLASH,$(img))))

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------

.PHONY: push-all push-ray push-improc push-specproc push-latest-tags
.PHONY: push/python push-python push/ray-base push-ray-base

push-all: $(addprefix push/,$(DEFAULT_IMAGES))

push-ray: $(addprefix push/,$(RAY_IMAGES))

push-improc: $(addprefix push/,$(IMPROC_IMAGES)) ## push improc family

push-specproc: $(addprefix push/,$(SPECPROC_IMAGES)) ## push specproc family

# Production Ray push: bake TAG into manager env (RAY_IMAGE_TAG) — use BUILD_TAG=$(TAG).
#   TAG=$(date -u +%y.%m); make build-ray BUILD_TAG=$TAG TAG=$TAG && make push-ray TAG=$TAG BUILD_TAG=$TAG

push/python push-python:
	@echo "ERROR: python image is build-only (internal bake parent); never push to Harbor." >&2
	@exit 1

push/ray-base push-ray-base:
	@echo "ERROR: ray-base is build-only; push ray-manager and ray-worker." >&2
	@exit 1

# push sources from $(BUILD_TAG) — the same tag the image was BUILT with. A
# release build (e.g. BUILD_TAG=YY.MM) MUST be pushed with the same BUILD_TAG,
# otherwise the stale default :local image is silently re-tagged and pushed over
# the release tag. The guard fails loudly when the source image is missing, and
# refuses to push when the source is OLDER than the local :$(TAG) image (a
# downgrade — the exact stale-:local incident).
# Single image: make push-<name> or make push/<name>
# (push-improc / push-specproc / push-ray / push-all remain family aggregators)
define PUSH_IMAGE
	@name="$(1)"; \
	src="$(REGISTRY)/$(OWNER)/$$name:$(BUILD_TAG)"; \
	dst="$(REGISTRY)/$(OWNER)/$$name:$(TAG)"; \
	latest="$(REGISTRY)/$(OWNER)/$$name:latest"; \
	if ! docker image inspect "$$src" >/dev/null 2>&1; then \
		echo "ERROR: $$src not found locally — build it first (make build-$$name BUILD_TAG=$(BUILD_TAG))" >&2; \
		exit 1; \
	fi; \
	if docker image inspect "$$dst" >/dev/null 2>&1; then \
		src_ts="$$(docker image inspect --format '{{.Created}}' "$$src")"; \
		dst_ts="$$(docker image inspect --format '{{.Created}}' "$$dst")"; \
		if [[ "$$src_ts" < "$$dst_ts" ]]; then \
			echo "ERROR: $$src ($(BUILD_TAG)) is OLDER than local $$dst — push would downgrade $$name:$(TAG). Rebuild with BUILD_TAG=$(TAG) and push with the same." >&2; \
			exit 1; \
		fi; \
	fi; \
	echo "Pushing $$src ($(BUILD_TAG)) as $$dst and $$latest"; \
	docker tag "$$src" "$$dst"; \
	docker push "$$dst"; \
	docker tag "$$src" "$$latest"; \
	docker push "$$latest"
endef

HYPHEN_PUSH_IMAGES := $(filter-out improc specproc,$(ALL_IMAGES))

define PUSH_HYPHEN
.PHONY: push-$(1)
push-$(1):
	$$(call PUSH_IMAGE,$(1))
endef
$(foreach img,$(HYPHEN_PUSH_IMAGES),$(eval $(call PUSH_HYPHEN,$(img))))

define PUSH_SLASH
.PHONY: push/$(1)
push/$(1):
	$$(call PUSH_IMAGE,$(1))
endef
$(foreach img,$(ALL_IMAGES),$(eval $(call PUSH_SLASH,$(img))))

# Disk-safe Harbor release: bake streams straight to the registry (no --load).
# Requires docker login to $(REGISTRY). TAG defaults to YY.MM.
# Also publishes :latest via registry-side retag (no local image download).
push-latest-tags: ## point :latest at existing :$(TAG) digests in Harbor
	@for img in $(IMAGES); do \
		src="$(IMAGE_PREFIX)/$$img:$(TAG)"; \
		dst="$(IMAGE_PREFIX)/$$img:latest"; \
		echo "latest ← $$src"; \
		docker buildx imagetools create -t "$$dst" "$$src"; \
	done

.PHONY: release-push release-push-ray release-push-improc release-push-specproc
release-push: ## bake+push the public release group to Harbor as :$(TAG) and :latest
	TAG=$(TAG) docker buildx bake --push release
	@$(MAKE) push-latest-tags IMAGES="$(SESSION_IMAGES)" TAG=$(TAG)

release-push-ray: ## bake+push ray-manager + ray-worker as :$(TAG) and :latest
	TAG=$(TAG) docker buildx bake --push ray-manager ray-worker
	@$(MAKE) push-latest-tags IMAGES="$(RAY_IMAGES)" TAG=$(TAG)

release-push-improc: ## bake+push improc family as :$(TAG) and :latest
	TAG=$(TAG) docker buildx bake --push $(IMPROC_IMAGES)
	@$(MAKE) push-latest-tags IMAGES="$(IMPROC_IMAGES)" TAG=$(TAG)

release-push-specproc: ## bake+push specproc family as :$(TAG) and :latest
	TAG=$(TAG) docker buildx bake --push $(SPECPROC_IMAGES)
	@$(MAKE) push-latest-tags IMAGES="$(SPECPROC_IMAGES)" TAG=$(TAG)

# ---------------------------------------------------------------------------
# Local tests
# ---------------------------------------------------------------------------

.PHONY: test-local test-agent-local test-studio-local test-dsh-local test-ray
.PHONY: test-improc-local test-specproc-local test-base-local test-host

test-local: ## verify session images (parallel)
	@fails=0; pids=(); \
	for img in $(DEFAULT_IMAGES); do \
		./scripts/test-local.sh "$$img" --verify-only & pids+=($$!); \
	done; \
	for pid in "$${pids[@]}"; do wait "$$pid" || fails=$$((fails + 1)); done; \
	if [[ "$$fails" -gt 0 ]]; then echo "$$fails image(s) failed." >&2; exit 1; fi
	./scripts/test-work-overlay.sh
	./scripts/test-status-arc-project.sh

# Runs the default images — DEFAULT_IMAGES is the canonical list (pass it so
# adding/removing an image stays single-sourced). For a single-image dev run
# use the script directly after building it: make build-studio &&
# ./scripts/test-agent-local.sh studio (no build-all dependency).
# SKIP_BUILD=1 reuses already-loaded local tags (avoids a full bake).
test-agent-local: ## agent command matrix on all session images (local, mounted fresh home)
	@if [ "$(SKIP_BUILD)" != "1" ]; then $(MAKE) build-all BUILD_TAG=$(BUILD_TAG); fi
	@chmod +x scripts/test-agent-local.sh
	@TAG=$(BUILD_TAG) ./scripts/test-agent-local.sh $(if $(IMAGE),$(IMAGE),$(DEFAULT_IMAGES))
	@echo "agent-local E2E passed for $(if $(IMAGE),$(IMAGE),all default images)"

test-studio-local: ## Studio Connect regression: stamp + dangling ~/.dsh → token → 200
	@chmod +x scripts/test-studio-local.sh
	@TAG=$(BUILD_TAG) ./scripts/test-studio-local.sh

test-dsh-local: ## dsh image: Connect token, Agent + Lab tabs, Lab auth via proxy, onboarding
	@chmod +x scripts/test-dsh-local.sh
	@TAG=$(BUILD_TAG) ./scripts/test-dsh-local.sh

test-ray: build-ray build-base ## Ray image checks + local cluster join + UI
	chmod +x scripts/test-ray-*.sh scripts/test-astroai-lab-loop.sh scripts/ray-head-start.sh \
		scripts/startup-ray-manager.sh scripts/ray-network-probe.sh ray/worker/start-worker.sh
	./scripts/test-ray-containers.sh $(if $(filter 1,$(SMOKE)),--smoke,)
	./scripts/test-ray-local.sh $(if $(filter 1,$(SMOKE)),--smoke,)
	./scripts/test-ray-cluster-local.sh $(if $(filter 1,$(SMOKE)),--smoke,)
	./scripts/test-ray-ui-local.sh $(if $(filter 1,$(SMOKE)),--smoke,)
	./scripts/test-astroai-lab-loop.sh $(if $(filter 1,$(SMOKE)),--smoke,)

test-improc-local: ## verify improc CLIs (build first: make build-improc)
	chmod +x scripts/test-improc-local.sh
	./scripts/test-improc-local.sh $(BUILD_TAG)

test-specproc-local: ## verify specproc family (build first: make build-specproc)
	chmod +x scripts/test-specproc-local.sh
	./scripts/test-specproc-local.sh $(BUILD_TAG)

test-base-local: ## run every base CLI for real (not just command -v)
	chmod +x scripts/test-base-local.sh
	./scripts/test-base-local.sh $(BUILD_TAG)

# ---------------------------------------------------------------------------
# CANFAR post-push tests
# ---------------------------------------------------------------------------

.PHONY: test-canfar test-canfar-agents test-canfar-session
.PHONY: test-canfar-ray test-canfar-ray-gpu test-canfar-ray-autoscale

test-canfar:
	./scripts/test-canfar.sh $(or $(IMAGE),base) $(TAG)

test-canfar-agents: ## post-push agent verb-surface probe on CANFAR (lightweight, no installs)
	CANFAR_TEST_AGENTS=1 ./scripts/test-canfar.sh $(or $(IMAGE),base) $(TAG)
	@echo "CANFAR agent verb-surface verification passed for $(or $(IMAGE),base):$(TAG)"

test-canfar-session: ## post-push: Running + connectURL HTTP + log fatal scan
	chmod +x scripts/test-canfar-session.sh
	./scripts/test-canfar-session.sh $(or $(IMAGE),terminal) $(TAG)

test-canfar-ray: ## CANFAR manager UI + 2-worker cluster lifecycle
	chmod +x scripts/test-canfar-ray.sh
	./scripts/test-canfar-ray.sh $(TAG)

test-canfar-ray-gpu: ## CANFAR 1-worker cluster with gpu=1
	chmod +x scripts/test-canfar-ray.sh
	CANFAR_RAY_GPUS=1 CANFAR_RAY_WORKER_COUNT=1 CANFAR_RAY_MIN_JOINED=1 \
		./scripts/test-canfar-ray.sh $(TAG)

test-canfar-ray-autoscale: ## CANFAR Ray autoscaler: bootstrap env + scale-up/down
	chmod +x scripts/test-canfar-ray.sh scripts/bootstrap-ray-manager-env.sh
	CANFAR_RAY_AUTOSCALING=1 ./scripts/test-canfar-ray.sh $(TAG)

# ---------------------------------------------------------------------------
# Clean / lint
# ---------------------------------------------------------------------------

.PHONY: clean clean-all lint-doc-quota lint ray-launch harbor-cleanup

harbor-cleanup: ## Harbor GC: keep this+prior YY.MM + latest (DRY_RUN=1 to preview)
	@chmod +x scripts/harbor-cleanup.sh
	@./scripts/harbor-cleanup.sh

clean:
	@imgs=($$(docker images --format '{{.Repository}}:{{.Tag}}' '$(IMAGE_PREFIX)/*' 2>/dev/null || true)); \
	if [[ $${#imgs[@]} -eq 0 || -z "$${imgs[0]}" ]]; then \
		echo "No $(IMAGE_PREFIX)/* images to remove."; \
	else \
		for img in "$${imgs[@]}"; do \
			docker rmi -f "$$img" 2>/dev/null || true; \
		done; \
		echo "Removed $(IMAGE_PREFIX)/* images."; \
	fi

clean-all: clean
	docker buildx prune -f

lint-doc-quota: ## forbid test-canfar.sh from reintroducing the false 'headless consumes quota' claim
	chmod +x scripts/lint-doc-quota.sh
	./scripts/lint-doc-quota.sh

test-host: ## docker-free checks (selfchecks + agent-wizard unit tests)
	chmod +x scripts/peek_selfcheck.sh scripts/osc52_copy_selfcheck.sh scripts/lib/test_astroai_boot_log.sh scripts/lib/test_astroai_whats_new.sh
	./scripts/peek_selfcheck.sh
	./scripts/osc52_copy_selfcheck.sh
	./scripts/lib/test_astroai_boot_log.sh
	./scripts/lib/test_astroai_whats_new.sh
	python3 scripts/lib/test_agent_wizard_verbs.py
	python3 scripts/lib/test_orx_canfar_proxy.py
	python3 scripts/lib/test_studio_canfar_proxy.py
	python3 scripts/lib/test_dsh_canfar_proxy.py
	python3 scripts/lib/test_astroai_html_proxy.py
	python3 scripts/lib/test_session_title.py
	python3 scripts/lib/test_canfar_marimo_env.py
	@! grep -F '[AstroAI]' config/starship.toml
	@! grep -E 'format = "in ' config/starship.toml
	@grep -q 'disabled = true' config/starship.toml

lint: ## doc-quota guard + dock-asset drift + docker-free host tests
	$(MAKE) lint-doc-quota
	$(MAKE) desk-assets-check
	$(MAKE) test-host

ray-launch:
	./scripts/ray-launch.sh
