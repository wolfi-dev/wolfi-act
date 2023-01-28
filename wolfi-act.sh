#!/usr/bin/env bash

set -ex
trap "rm -f wolfi-act.apko.config wolfi-act.tar" EXIT

CMD=$@
[[ "${CMD}" != "" ]] || CMD="echo \"Hello from wolfi-act!\""

cat >./wolfi-act.apko.config <<EOL
contents:
  repositories:
    - https://packages.wolfi.dev/os
  keyring:
    - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
  packages:
    - ca-certificates-bundle
    - wolfi-baselayout
    - busybox
    - bash
    - grype
EOL

docker run --rm \
    -v ${PWD}:/work \
    -w /work \
    ghcr.io/wolfi-dev/apko:latest \
    build \
    --build-arch x86_64 \
    --sbom=false \
    wolfi-act.apko.config \
    wolfi-act:latest \
    wolfi-act.tar

docker load < wolfi-act.tar

docker run --rm --platform linux/amd64 \
    -v ${PWD}:/work \
    -w /work \
    wolfi-act:latest \
    bash -exc "${CMD}"
