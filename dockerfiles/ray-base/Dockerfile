# syntax=docker/dockerfile:1
# Slim Ray runtime — FROM python (not fat interactive base).
# Used by ray-worker only. Managers stay on fat base for scientist shell/UI.

ARG PYTHON_VERSION=3.13

FROM astroai-python:${PYTHON_VERSION}

LABEL org.opencontainers.image.title="AstroAI Ray Base (slim)" \
      org.opencontainers.image.description="Minimal Ray + canfar-lab for workers"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    procps \
    rsync \
    && rm -rf /var/lib/apt/lists/*

ENV TERM=xterm-256color \
    SHELL=/bin/bash \
    WORK=/srcdir \
    SCRATCH=/scratch

RUN printf '%s\n' \
    '[ -f /etc/profile.d/astroai.sh ] && . /etc/profile.d/astroai.sh' \
    >> /etc/bash.bashrc

COPY scripts/astroai-profile.sh /etc/profile.d/astroai.sh
RUN chmod a+r /etc/profile.d/astroai.sh

RUN mkdir -p /opt/astroai/{bin,cache,lib,venv} /cadc "${WORK}" \
    && chmod -R a+rX /opt/astroai \
    && chmod -R a+rwx /opt/astroai/cache \
    && chmod 1777 "${WORK}"  # /srcdir stays writable (clone --dir /srcdir)

# Minimal lab + Ray. canfar-lab floats; Ray is exact-pinned in ray-deps.txt so
# manager and worker share one cluster ABI (same Ray + PYTHON_VERSION).
COPY config/canfar-lab.txt config/ray-deps.txt /tmp/
COPY scripts/lib/assert-image-python.sh scripts/lib/install-ray-venv.sh /opt/astroai/lib/
ADD https://pypi.org/pypi/canfar-lab/json /tmp/canfar-lab-pypi.json
RUN chmod a+rx /opt/astroai/lib/assert-image-python.sh /opt/astroai/lib/install-ray-venv.sh \
    && ln -sf /opt/astroai/lib/assert-image-python.sh /usr/local/bin/assert-image-python \
    && uv venv --python python3 /opt/canfar \
    && assert-image-python /opt/canfar/bin/python \
    && uv pip install --python /opt/canfar -r /tmp/canfar-lab.txt \
    && chmod -R a+rwX /opt/canfar \
    && mkdir -p /etc/astroai-lab \
    && /opt/canfar/bin/python -c "import importlib.resources as r, shutil; p=r.files('canfar_lab.data.shell'); shutil.copy(p.joinpath('profile.sh'), '/etc/astroai-lab/profile.sh'); shutil.copy(p.joinpath('hooks.sh'), '/etc/astroai-lab/hooks.sh')" \
    && chmod a+r /etc/astroai-lab/profile.sh /etc/astroai-lab/hooks.sh \
    && test -f /etc/astroai-lab/profile.sh \
    && test -f /etc/astroai-lab/hooks.sh \
    && HOME=/tmp WORK=/srcdir SCRATCH=/scratch \
       /opt/canfar/bin/canfar-lab env export --no-ensure >/dev/null \
    && uv venv --python python3 /opt/astroai/venv/ray \
    && assert-image-python /opt/astroai/venv/ray/bin/python \
    && bash /opt/astroai/lib/install-ray-venv.sh /opt/astroai/venv/ray /tmp/ray-deps.txt \
    && uv pip install --python /opt/astroai/venv/ray -r /tmp/canfar-lab.txt \
    && rm -f /tmp/ray-deps.txt /tmp/canfar-lab.txt /tmp/canfar-lab-pypi.json \
    && uv cache clean

COPY scripts/lib/astroai-env-common.sh scripts/lib/astroai-ui.sh /opt/astroai/lib/

ENV PATH="/opt/astroai/venv/ray/bin:/opt/canfar/bin:${PATH}"

COPY ray/worker/start-worker.sh /opt/astroai/bin/start-ray-worker.sh
COPY scripts/ray-head-start.sh /opt/astroai/bin/ray-head-start.sh
COPY scripts/ray-network-probe.sh /opt/astroai/bin/ray-network-probe.sh
COPY scripts/lib/ray-version.sh /opt/astroai/lib/ray-version.sh
COPY examples/ray/ /opt/astroai/examples/ray/
COPY docs/USAGE.md /opt/astroai/USAGE.md
RUN chmod a+rx /opt/astroai/bin/start-ray-worker.sh /opt/astroai/bin/ray-head-start.sh \
    /opt/astroai/bin/ray-network-probe.sh \
    && chmod a+rx /opt/astroai/lib/*
