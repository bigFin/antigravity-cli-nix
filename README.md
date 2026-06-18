# antigravity-cli-nix

Nix wrappers for the closed-source Google Antigravity CLI.

The upstream CLI is distributed through an installer rather than source code or
GitHub releases. This repository provides two packages:

- `agy-fhs-live`: the default. Use this for normal daily use.
- `agy-bin`: the pinned fallback. Use this when you want a fixed version in the
  Nix store.
- `agy-sandboxed`: a stricter Linux-only wrapper around `agy-bin` for running
  against one workspace with a scrubbed environment and private home.

## Which Package?

Use `agy-fhs-live` unless you have a specific reason not to. It installs the real
`agy` binary under XDG data, runs it in an FHS environment, and lets Google's
self-update behavior work normally.

Use `agy-bin` when reproducibility matters more than matching Google's update
model. It fetches one manifest-pinned tarball into `/nix/store`, so it is useful
for rollback, CI, and version checks. It should not be expected to self-update.

`agy-fhs-live` is Linux-only because it uses an FHS environment. `agy-bin`
supports `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, and
`aarch64-darwin`. `agy-sandboxed` is Linux-only because it uses bubblewrap.

## Usage

Run the live wrapper:

```sh
nix run .#agy-fhs-live
```

Run the pinned package:

```sh
nix run .#agy-bin
```

Run the sandboxed wrapper:

```sh
nix run .#agy-sandboxed -- --version
```

Install through Home Manager or NixOS:

```nix
{
  home.packages = [
    inputs.antigravity-cli-nix.packages.${pkgs.system}.agy-fhs-live
  ];
}
```

On macOS, use `agy-bin`:

```sh
nix run .#agy-bin
```

## Mutable Live Wrapper

The live wrapper keeps the upstream binary outside `/nix/store`:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/antigravity-cli/agy
```

Override the location with:

```sh
ANTIGRAVITY_CLI_HOME=/some/path nix run .#agy-fhs-live
```

This makes updates possible, but those updates are not pinned by `flake.lock`.

The wrapper does not pipe Google's `install.sh` into a shell. It reads the
installer to discover the current manifest host, then performs the manifest
lookup, SHA-512 verification, and tarball extraction itself. This avoids the
upstream installer's shell profile editing step inside the FHS environment.

The live wrapper has been tested locally for bootstrap, login, and normal
authenticated CLI usage on `x86_64-linux`.

## Sandboxed Wrapper

`agy-sandboxed` is an opt-in wrapper for a stricter threat model. It runs the
pinned `agy-bin` binary through bubblewrap with:

- a scrubbed environment
- a private home under
  `${XDG_DATA_HOME:-$HOME/.local/share}/antigravity-cli-sandbox/home`
- the selected workspace mounted at `/workspace`
- `/nix/store` mounted read-only
- network access still enabled

By default, the selected workspace is the current directory. Override it with:

```sh
AGY_SANDBOX_WORKSPACE=/path/to/project nix run .#agy-sandboxed
```

Override sandbox state with:

```sh
AGY_SANDBOX_HOME=/path/to/sandbox-state nix run .#agy-sandboxed
```

This wrapper intentionally does not expose your normal home directory, shell
environment, SSH agent, or global cloud credentials. It is more isolated, but
some commands or auth flows may require additional explicit mounts or setup.

To expose your SSH agent inside the sandbox, opt in explicitly:

```sh
AGY_ALLOW_SSH=1 nix run .#agy-sandboxed
```

The workspace is writable by default so the CLI can edit code. For read-only
analysis, use a copied workspace or mount policy changes in
`packages/agy-sandboxed.nix`.

## Pinned Binary

The pinned package fetches the tarball referenced by Google's platform manifest.

Refresh it with:

```sh
./scripts/update-pinned.sh
```

The updater reads Google's installer to discover the current manifest host, then
fetches manifests for all supported pinned platforms:

```text
<download-base-url>/manifests/<platform>.json
```

then updates `packages/pin.json` with the latest URLs and Nix hashes.

## CI

The included workflows check formatting, evaluate and build the flake, refresh
the pinned Antigravity CLI package, and refresh flake inputs.

Scheduled update PRs on the `update/antigravity-cli` and `update/flake-lock`
branches can run without manual workflow approval, receive an automatic PR
review approval, and queue auto-merge after required checks pass. This requires
two repository secrets:

- `UPDATE_PR_TOKEN`: a fine-grained PAT or GitHub App token that can write
  contents and pull requests. The update workflows use this to create the PR and
  enable auto-merge.
- `AUTO_APPROVE_TOKEN`: a separate fine-grained PAT or bot token that can write
  pull request reviews. A separate token is used because GitHub generally does
  not allow the same actor that opened a PR to approve it.

Repository auto-merge must also be enabled, and branch protection for `main`
should require the CI status checks and at least one approving review.

The update workflows intentionally restrict their generated PRs to the expected
files only: `packages/pin.json` for Antigravity CLI updates and `flake.lock` for
flake input updates. Token-consuming actions are pinned to full commit SHAs;
Dependabot checks GitHub Actions weekly and opens PRs when those pins should be
updated. Review those PRs manually because action code runs in workflows that
can receive credentials.

The live package should not be auto-mutated by CI. It is intentionally a runtime
bootstrapper.

## License

The Nix expressions and scripts in this repository are MIT-licensed. Google
Antigravity CLI itself is proprietary software by Google.
