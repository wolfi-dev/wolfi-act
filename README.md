# wolfi-act

![](./wolfi-act.jpg)

Dynamic GitHub Actions from [Wolfi](https://wolfi.dev/) packages

Never worry again about installing your favorite tools using upstream "installer"
actions or whatever is available in GitHub via `apt-get`.

This action builds an ephermeral container image from the latest Wolfi packages
and runs your command inside of it.

## Usage

Pass in `packages` with a comma-separated list of packages available in
Wolfi, along with a `command` you wish to run.

```yaml
- uses: wolfi-dev/wolfi-act@main
  with:
    packages: jq,cosign
    command: |
      jq --version
      cosign --version
```

### Example: run a grype and trivy scan on an image

Source: [grype-trivy-scan-example.yaml](./examples/grype-trivy-scan-example.yaml)

```yaml
# .github/workflows/grype-trivy-scan-example.yaml
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
jobs:
  wolfi-act:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write # needed for GitHub  OIDC Token
    steps:
      - uses: actions/checkout@v3
      - uses: wolfi-dev/wolfi-act@main
        with:
          packages: curl,apko,cosign,crane
          command: |
            set -x
            grype cgr.dev/chainguard/nginx
            trivy image cgr.dev/chainguard/nginx
```

### Example: build, push, sign, and tag an image

Source: [oci-image-push-sign-tag-example.yaml](./examples/oci-image-push-sign-tag-example.yaml)

```yaml
# .github/workflows/oci-image-push-sign-tag-example.yaml
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
jobs:
  wolfi-act:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write # needed for GitHub  OIDC Token
    steps:
      - uses: actions/checkout@v3
      - uses: wolfi-dev/wolfi-act@main
        env:
          OCI_HOST: ghcr.io
          OCI_REPO: ${{ github.repository }}/wolfi-act-demo
          OCI_USER: ${{ github.repository_owner }}
          OCI_PASS: ${{ github.token }}
          OCI_TAG: latest
          APKO_ARCHS: x86_64,aarch64
          APKO_KEYS: https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
          APKO_REPOS: https://packages.wolfi.dev/os
          APKO_DEFAULT_CONF: https://raw.githubusercontent.com/chainguard-images/images/main/images/wolfi-base/configs/latest.apko.yaml
        with:
          packages: curl,apko,cosign,crane
          command: |
            set -x

            # Make sure repo has an apko.yaml file, otherwise use default
            if [[ ! -f apko.yaml ]]; then
              echo "Warning: no apko.yaml in repo, downloading from $APKO_DEFAULT_CONF"
              curl -sL -o apko.yaml $APKO_DEFAULT_CONF
            fi

            # Login to OCI registry
            apko login $OCI_HOST -u $OCI_USER -p $OCI_PASS

            # Publish image with apko and capture the index digest
            digest=$(apko publish --arch $APKO_ARCHS \
                       -k $APKO_KEYS -r $APKO_REPOS \
                       apko.yaml $OCI_HOST/$OCI_REPO)

            # Sign with cosign
            cosign sign --yes $digest

            # Lastly, tag the image with crane
            crane copy $digest $OCI_HOST/$OCI_REPO:$OCI_TAG
```


### Example: run multiple versions of kubectl using build matrix

Source: [multiple-versions-of-kubectl-example.yaml](./examples/multiple-versions-of-kubectl-example.yaml)

```yaml
# .github/workflows/multiple-versions-of-kubectl-example.yaml
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
jobs:
  wolfi-act:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        wolfi_pkg_name_kubectl:
          - kubectl-1.24
          - kubectl-1.25
          - kubectl-1.26
          - kubectl # note: this is 1.27 or latest
    steps:
      - uses: actions/checkout@v3
      - uses: wolfi-dev/wolfi-act@main
        with:
          packages: ${{ matrix.wolfi_pkg_name_kubectl }}
          command: |
            set -x

            # Make a symlink when "kubectl" is not the name of the binary in the package
            if [[ "${{ matrix.wolfi_pkg_name_kubectl }}" != "kubectl" ]]; then
              ln -sf /usr/bin/${{ matrix.wolfi_pkg_name_kubectl }} /usr/bin/kubectl
            fi

            kubectl version --client
```
