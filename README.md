# wolfi-act
Dynamic GitHub Actions from Wolfi packages

## Usage

For example, run a grype scan:

```yaml
- uses: jdolitsky/wolfi-act@main
    with:
    packages: grype
    command: grype cgr.dev/chainguard/nginx
```

TODO: pass in the github env
