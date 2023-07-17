#!/usr/bin/env bash

set -e
trap "rm -f wolfi-act.apko.config.yaml wolfi-act.tar" EXIT

CMD=$@
[[ "${CMD}" != "" ]] || CMD="echo \"Hello from wolfi-act!\""

cat >./wolfi-act.apko.config.yaml <<EOL
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
EOL

printf "Building ephemeral container image from Wolfi packages... "
docker run --rm \
    -v ${PWD}:/work \
    -w /work \
    ghcr.io/wolfi-dev/apko:latest \
    build \
    --arch x86_64 \
    --sbom=false \
    wolfi-act.apko.config.yaml \
    wolfi-act:latest \
    wolfi-act.tar 2>/dev/null
echo "done."

printf "Loading ephemeral container image into Docker... "
docker load < wolfi-act.tar >/dev/null
echo "done."

echo "Running the following command in ephemeral container image: ${CMD}"
echo "Output:"
docker run -i --rm --platform linux/amd64 \
    -v ${PWD}:/work \
    -w /work \
    wolfi-act:latest \
    bash -ec "${CMD}"
