# AstroAI container stack — build with: docker buildx bake

variable "REGISTRY" {
  default = "images.canfar.net"
}

variable "OWNER" {
  default = "astroai"
}

variable "TAG" {
  default = "local"
}

# dsh for the Studio images: an exact version, or "newest" to resolve inside the
# build. `make build-studio` sets it to the newest release (scripts/dsh-newest.sh).
variable "DSH_VERSION" {
  default = "newest"
}

# Local canfar-lab wheel dir for the Studio images (empty: latest from PyPI).
# make sets it to ../canfar-lab/dist when that holds a wheel.
variable "CANFAR_LAB_DIST" {
  default = ""
}

variable "PYTHON_VERSION" {
  default = "3.13"
}

# make build-all / release-push. marimo, vscode, notebook and the improc/specproc
# terminal and notebook variants remain as targets, not in this group (Studio
# covers them; make build-<name>). ray-base and python are bake parents,
# not Harbor images.
group "default" {
  targets = [
    "base",
    "improc",
    "specproc",
    "openscience",
    "openresearch",
    "ray-worker",
    "ray-manager",
    "studio",
    "improc-studio",
    "specproc-studio",
    "terminal",
  ]
}

# Same set as default. release-push bakes this group straight to Harbor.
group "release" {
  targets = [
    "base",
    "improc",
    "specproc",
    "openscience",
    "openresearch",
    "ray-worker",
    "ray-manager",
    "studio",
    "improc-studio",
    "specproc-studio",
    "terminal",
  ]
}

group "improc" {
  targets = ["improc", "improc-studio"]
}

group "specproc" {
  targets = ["specproc", "specproc-studio"]
}

# Untagged bake parent. Never a Harbor image.
target "python" {
  context    = "./dockerfiles/python"
  dockerfile = "Dockerfile"
  args = {
    PYTHON_VERSION = "${PYTHON_VERSION}"
  }
}

target "base" {
  context    = "."
  dockerfile = "dockerfiles/base/Dockerfile"
  contexts = {
    "astroai-python:${PYTHON_VERSION}" = "target:python"
  }
  tags = ["${REGISTRY}/${OWNER}/base:${TAG}"]
  args = {
    PYTHON_VERSION = "${PYTHON_VERSION}"
  }
}

target "_interface" {
  context = "."
  contexts = {
    "${REGISTRY}/${OWNER}/base:${TAG}" = "target:base"
  }
  args = {
    REGISTRY  = "${REGISTRY}"
    OWNER     = "${OWNER}"
    BASE_NAME = "base"
    TAG       = "${TAG}"
  }
}

target "terminal" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/terminal/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/terminal:${TAG}"]
}

target "notebook" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/notebook/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/notebook:${TAG}"]
}

target "vscode" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/vscode/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/vscode:${TAG}"]
}

target "marimo" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/marimo/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/marimo:${TAG}"]
}

target "openresearch" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/openresearch/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/openresearch:${TAG}"]
}

target "openscience" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/openscience/Dockerfile"
  tags       = ["${REGISTRY}/${OWNER}/openscience:${TAG}"]
}

# CANFAR Studio: dsh Chat + Terminal, JupyterLab, marimo, VS Code and Settings
# tabs (docs/STUDIO.md). An unreleased canfar-lab wheel:
#   --set studio.contexts.canfar-lab-dist=../canfar-lab/dist
target "studio" {
  inherits   = ["_interface"]
  dockerfile = "dockerfiles/studio/Dockerfile"
  contexts   = CANFAR_LAB_DIST != "" ? { "canfar-lab-dist" = CANFAR_LAB_DIST } : {}
  tags       = ["${REGISTRY}/${OWNER}/studio:${TAG}"]
  args = {
    DSH_VERSION = "${DSH_VERSION}"
  }
}

# Ray cluster images
# - ray-base: slim (from python) → ray-worker
# - ray-manager: fat (from base) + Ray runtime
target "ray-base" {
  context    = "."
  dockerfile = "dockerfiles/ray-base/Dockerfile"
  contexts = {
    "astroai-python:${PYTHON_VERSION}" = "target:python"
  }
  tags = ["${REGISTRY}/${OWNER}/ray-base:${TAG}"]
  args = {
    PYTHON_VERSION = "${PYTHON_VERSION}"
  }
}

target "ray-worker" {
  context    = "."
  dockerfile = "dockerfiles/ray-worker/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/ray-base:${TAG}" = "target:ray-base"
  }
  tags = ["${REGISTRY}/${OWNER}/ray-worker:${TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    OWNER    = "${OWNER}"
    TAG      = "${TAG}"
  }
}

target "ray-manager" {
  context    = "."
  dockerfile = "dockerfiles/ray-manager/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/base:${TAG}" = "target:base"
  }
  tags = ["${REGISTRY}/${OWNER}/ray-manager:${TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    OWNER    = "${OWNER}"
    TAG      = "${TAG}"
  }
}

# Headless astronomy image-processing CLIs (FITS/HDF5). Parent of improc-studio.
target "improc" {
  context    = "."
  dockerfile = "dockerfiles/improc/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/base:${TAG}" = "target:base"
  }
  tags = ["${REGISTRY}/${OWNER}/improc:${TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    OWNER    = "${OWNER}"
    TAG      = "${TAG}"
  }
}

# Studio on improc. Same Dockerfile as studio; improc is the default Python.
target "improc-studio" {
  context    = "."
  dockerfile = "dockerfiles/studio/Dockerfile"
  contexts = merge(
    { "${REGISTRY}/${OWNER}/improc:${TAG}" = "target:improc" },
    CANFAR_LAB_DIST != "" ? { "canfar-lab-dist" = CANFAR_LAB_DIST } : {},
  )
  tags = ["${REGISTRY}/${OWNER}/improc-studio:${TAG}"]
  args = {
    REGISTRY    = "${REGISTRY}"
    OWNER       = "${OWNER}"
    BASE_NAME   = "improc"
    TAG         = "${TAG}"
    DSH_VERSION = "${DSH_VERSION}"
  }
}

# Terminal on improc (ghostty-web + science PATH).
target "improc-terminal" {
  context    = "."
  dockerfile = "dockerfiles/terminal/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/improc:${TAG}" = "target:improc"
  }
  tags = ["${REGISTRY}/${OWNER}/improc-terminal:${TAG}"]
  args = {
    REGISTRY  = "${REGISTRY}"
    OWNER     = "${OWNER}"
    BASE_NAME = "improc"
    TAG       = "${TAG}"
  }
}

# Headless spectroscopy stack (in build-all / release). Vendors pPXF and MOOG —
# catalog image with redistribution caveats; see docs/OPERATORS.md.
target "specproc" {
  context    = "."
  dockerfile = "dockerfiles/specproc/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/base:${TAG}" = "target:base"
  }
  tags = ["${REGISTRY}/${OWNER}/specproc:${TAG}"]
  args = {
    REGISTRY = "${REGISTRY}"
    OWNER    = "${OWNER}"
    TAG      = "${TAG}"
  }
}

# Studio on specproc. Same Dockerfile as studio; specproc is the default Python.
target "specproc-studio" {
  context    = "."
  dockerfile = "dockerfiles/studio/Dockerfile"
  contexts = merge(
    { "${REGISTRY}/${OWNER}/specproc:${TAG}" = "target:specproc" },
    CANFAR_LAB_DIST != "" ? { "canfar-lab-dist" = CANFAR_LAB_DIST } : {},
  )
  tags = ["${REGISTRY}/${OWNER}/specproc-studio:${TAG}"]
  args = {
    REGISTRY    = "${REGISTRY}"
    OWNER       = "${OWNER}"
    BASE_NAME   = "specproc"
    TAG         = "${TAG}"
    DSH_VERSION = "${DSH_VERSION}"
  }
}

# Terminal on specproc (ghostty-web + science PATH).
target "specproc-terminal" {
  context    = "."
  dockerfile = "dockerfiles/terminal/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/specproc:${TAG}" = "target:specproc"
  }
  tags = ["${REGISTRY}/${OWNER}/specproc-terminal:${TAG}"]
  args = {
    REGISTRY  = "${REGISTRY}"
    OWNER     = "${OWNER}"
    BASE_NAME = "specproc"
    TAG       = "${TAG}"
  }
}

target "specproc-notebook" {
  context    = "."
  dockerfile = "dockerfiles/specproc-notebook/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/specproc:${TAG}" = "target:specproc"
  }
  tags = ["${REGISTRY}/${OWNER}/specproc-notebook:${TAG}"]
  args = {
    REGISTRY  = "${REGISTRY}"
    OWNER     = "${OWNER}"
    BASE_NAME = "specproc"
    TAG       = "${TAG}"
  }
}

# JupyterLab on improc — default kernel is the science venv.
target "improc-notebook" {
  context    = "."
  dockerfile = "dockerfiles/improc-notebook/Dockerfile"
  contexts = {
    "${REGISTRY}/${OWNER}/improc:${TAG}" = "target:improc"
  }
  tags = ["${REGISTRY}/${OWNER}/improc-notebook:${TAG}"]
  args = {
    REGISTRY  = "${REGISTRY}"
    OWNER     = "${OWNER}"
    BASE_NAME = "improc"
    TAG       = "${TAG}"
  }
}
