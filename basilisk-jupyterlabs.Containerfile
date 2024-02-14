FROM python:3.10.9-bullseye AS builder

RUN apt-get update && apt-get install --no-install-recommends -y \
        build-essential \
        cmake \
        python3-setuptools \
        swig \
        && rm -rf /var/lib/apt/lists/*

RUN adduser basiliskuser
USER basiliskuser

RUN mkdir /home/basiliskuser/bsk-build
WORKDIR /home/basiliskuser/bsk-build

ADD ./basilisk .

ENV PATH="/home/basiliskuser/.local/bin:${PATH}"
RUN pip install --upgrade pip
RUN pip install --user conan==1.62.0

ENV CONAN_REVISIONS_ENABLED=1
RUN conan install . --build=missing -s build_type=Release -if dist3/conan -o opNav=False -o vizInterface=False -o autoKey=u
RUN conan build . -if dist3/conan


# Second build stage only contains pip installed bsk build products,
# example scenarios, and support data directories
FROM python:3.10.9-bullseye

LABEL org.opencontainers.artifact.description="Basilisk Jupyter Labs Python Development Environment"
LABEL org.opencontainers.image.documentation="https://github.com/lasp/basilisk-dev-environment"
LABEL org.opencontainers.image.source="https://github.com/lasp/basilisk-dev-environment"
LABEL org.opencontainers.image.licenses="MIT"

RUN apt-get update && apt-get install --no-install-recommends -y \
        curl \
        python3-setuptools \
        python3-tk \
        vim \
        && rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION=18.13.0
ENV NVM_DIR=/usr/src/.nvm
ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}"
RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash \
    &&. "$NVM_DIR/nvm.sh" \
    && nvm install -b ${NODE_VERSION} \
    && nvm use v${NODE_VERSION} \
    && nvm alias default v${NODE_VERSION} \
    && node --version \
    && npm --version

RUN adduser basiliskuser
USER basiliskuser

RUN mkdir /home/basiliskuser/python-workspace
RUN mkdir /home/basiliskuser/bsk-build
RUN mkdir /home/basiliskuser/bsk-build/dist3

# Copy the bsk build products and examples only (reduce image size)
COPY --chown=basiliskuser:basiliskuser --from=builder /home/basiliskuser/bsk-build/dist3/Basilisk /home/basiliskuser/bsk-build/dist3/Basilisk/
COPY --chown=basiliskuser:basiliskuser --from=builder /home/basiliskuser/bsk-build/dist3/Basilisk.egg-info /home/basiliskuser/bsk-build/dist3/Basilisk.egg-info/
COPY --chown=basiliskuser:basiliskuser ./basilisk/examples/ /home/basiliskuser/python-workspace/examples/
COPY --chown=basiliskuser:basiliskuser ./basilisk/supportData/ /home/basiliskuser/python-workspace/supportData/

WORKDIR /home/basiliskuser/bsk-build

# Have to add the following teo directories because bsk build symlinks them
# into the python package and podman/docker doesn't dereference the symlink.
ADD ./basilisk/src/utilities ./src/utilities/
ADD ./basilisk/supportData ./supportData/

# Have to copy the following for the setup.py run when pip installing bsk
COPY --chown=basiliskuser:basiliskuser ./requirements.txt .
COPY --chown=basiliskuser:basiliskuser ./basilisk/setup.py .
COPY --chown=basiliskuser:basiliskuser ./basilisk/LICENSE .
COPY --chown=basiliskuser:basiliskuser ./basilisk/README.md .
COPY --chown=basiliskuser:basiliskuser ./basilisk/docs/source/bskVersion.txt ./docs/source/bskVersion.txt

ENV PATH="/home/basiliskuser/.local/bin:${PATH}"
RUN pip install --upgrade pip
RUN pip install --user -r requirements.txt
RUN pip install --user -e .

WORKDIR /home/basiliskuser/python-workspace
EXPOSE 8888
ENTRYPOINT jupyter lab --ip 0.0.0.0 --allow-root
