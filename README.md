# wolfi-act

![istockphoto-486310559-612x612](https://github.com/jdolitsky/wolfi-act/assets/393494/4e0cc0c9-c5a3-461b-a085-2702351cf869)

Dynamic GitHub Actions from [Wolfi](https://wolfi.dev/) packages

Never worry again about installing your favorite tools using upstream "installer"
actions or whatever is available in GitHub via `apt-get`.

This action builds an ephermeral container image from the latest Wolfi packages
and runs your command inside of it.

## Usage

Pass in `packages` with a comma-separated list of packages available in
Wolfi, along with a `command` you wish to run.

### Example: run a grype and trivy scan on an image

```yaml
- uses: wolfi-dev/wolfi-act@main
  with:
    packages: grype,trivy
    command: |
      grype cgr.dev/chainguard/nginx
      trivy image cgr.dev/chainguard/nginx
```

### Example: full image publish pipeline

Here's a full Github Actions workflow example which does the following (source [here](./.github/workflows/build.yml)):

1. Installs tools: `curl`, `apko`, `cosign`, `crane`, `grype`, `trivy`
2. Downloads an apko config file using `curl`
3. Logs into GHCR using `crane`
4. Publishes a container image using `apko`
5. Signs the image using `cosign`
6. Scans the image with `grype` and `trivy`
7. Tags the image using `crane`
8. Ensure that the tagged image runs using `docker`

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
env:
  IMAGE_REPO: ghcr.io/${{ github.repository }}/wolfi-act-test
  APKO_CONFIG: https://raw.githubusercontent.com/chainguard-images/images/main/images/maven/configs/openjdk-17.apko.yaml
  GHCR_USER: ${{ github.repository_owner }}
  GHCR_PASS: ${{ github.token }}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write # needed for GitHub OIDC Token
    steps:
      - name: Build, sign, inspect an image using wolfi-act
        uses: wolfi-dev/wolfi-act@main
        with:
          packages: curl,apko,cosign,crane,grype,trivy
          command: |
            set -x

            # Download an apko config file
            curl -L -o apko.yaml "${APKO_CONFIG}"

            # Login to GHCR
            crane auth login ghcr.io -u "${GHCR_USER}" -p "${GHCR_PASS}"

            # Publish image using apko
            apko publish apko.yaml "${IMAGE_REPO}" \
              --repository-append=https://packages.wolfi.dev/os \
              --keyring-append=https://packages.wolfi.dev/os/wolfi-signing.rsa.pub \
              --package-append=wolfi-baselayout \
              --arch=x86_64,aarch64 \
              --image-refs=apko.images.txt | tee apko.index.txt
            index_digest="$(cat apko.index.txt)"

            # Sign image with cosign
            cosign sign --yes $(cat apko.images.txt)

            # Scan image with grype and trivy
            grype "${index_digest}"
            trivy image "${index_digest}"

            # Tag image using crane
            crane cp "${index_digest}" "${IMAGE_REPO}:latest"

      - name: Make sure the image runs
        run: |
          set -x
          docker run --rm "${IMAGE_REPO}:latest" --version

```
