set unstable := true
set positional-arguments := true

# Run [script] recipes under bash rather than the default sh. On Linux
# sh is dash, which lacks [[ ]], <<<, and set -o pipefail — constructs
# [script] recipes are free to rely on. macOS sh is bash, so a dash
# incompatibility would stay hidden locally until CI runs on Linux.
set script-interpreter := ['bash', '-eu']

# Locate a Docker-compatible container runtime. Probe PATH first, then
# well-known install locations so the recipe still works inside agentic
# harnesses or sandboxes that strip /usr/local/bin from PATH. Override by
# setting CONTAINER_RUNTIME in the environment.
container_runtime := env("CONTAINER_RUNTIME", `bash -c '
    docker_path=$(command -v docker 2>/dev/null || true)
    podman_path=$(command -v podman 2>/dev/null || true)
    for p in "$docker_path" \
             /usr/local/bin/docker \
             /opt/homebrew/bin/docker \
             /Applications/Docker.app/Contents/Resources/bin/docker \
             "$HOME/.orbstack/bin/docker" \
             "$HOME/.rd/bin/docker" \
             "$podman_path" \
             /opt/podman/bin/podman; do
        if [ -n "$p" ] && [ -x "$p" ]; then echo "$p"; exit 0; fi
    done
    echo docker
'`)

# actionlint version pin. The upstream image bundles actionlint (and
# the shellcheck it shells out to) at a known version, and actionlint
# has no PyPI distribution for the dev dependency group to carry, so
# we pin a Docker image by digest instead. Renovate tracks the
# version + digest pair below via the comment marker (the shared
# Justfile customManager from the org's renovate presets).
#
# renovate: datasource=docker depName=rhysd/actionlint
actionlint_version := "1.7.12"
actionlint_image := "docker.io/rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"

# actionlint invocation. Mounts the repo read-only at /repo with -w /repo
# so actionlint finds .github/workflows/ and .github/actionlint.yaml.
#
# DOCKER_CONFIG points at a fresh empty directory so docker skips the
# osxkeychain credential helper (public Docker Hub pulls don't need it,
# and sandboxed environments can't always reach the helper binary).
# PATH gets the runtime's directory prepended for cases where docker
# itself isn't on the calling shell's PATH. Shell substitutions
# evaluate at recipe-run time, not Justfile-parse time.
actionlint := 'DOCKER_CONFIG="$(mktemp -d)" PATH="$(dirname ' + container_runtime + '):$PATH" ' + container_runtime + ' run --rm -v "$(pwd):/repo:ro" -w /repo ' + actionlint_image

# Build metadata. `date` is the *committer date* (UTC, ISO-8601),
# not build invocation time, so two builds of the same commit produce
# identical artifacts. `source_date_epoch` exports the same instant as
# a unix timestamp for downstream tooling (BuildKit, archive tooling)
# that honors SOURCE_DATE_EPOCH for reproducibility.
#
# `--abbrev=7` / `--short=7` pin the abbreviated hash length so two
# checkouts of the same commit produce the same string. Without this,
# git uses `core.abbrev=auto`, whose length depends on object count
# (shallow clones, freshly-packed repos, and aged working copies all
# differ). 7 matches goreleaser's `.ShortCommit`.

commit := `git rev-parse --short=7 HEAD 2>/dev/null || echo ""`
date := `TZ=UTC git log -1 --format=%cd --date=format-local:%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown"`
source_date_epoch := `git log -1 --format=%ct 2>/dev/null || echo "0"`

# Default recipe
default: test

# --- Setup ---

# Set up development environment. New contributors run this once after
# cloning. Idempotent: re-running upgrades dependencies and refreshes
# Vale's synced style packages.
setup:
    just install-brew
    just install-tools

# Install Homebrew dependencies from Brewfile.
install-brew:
    brew bundle check || brew bundle install

# Refresh non-brew tooling. Today that means Vale's synced style
# packages; grows as new sync-style tools land.
install-tools:
    vale sync

# --- Build ---

# Write the generated _buildstamp module buildmeta reads commit and
# date from. Python has no ldflags to inject them at link time, so
# every recipe that builds or runs the tool depends on this one,
# regenerating the gitignored file to match the current checkout.
[script]
stamp:
    cat > src/proofhouse_python_tool/_buildstamp.py <<'EOF'
    # SPDX-License-Identifier: Apache-2.0
    # Copyright Authors of Proofhouse

    COMMIT = "{{ commit }}"
    DATE = "{{ date }}"
    EOF

# Build the sdist and wheel
build: stamp
    SOURCE_DATE_EPOCH={{ source_date_epoch }} uv build

# Check that builds are reproducible: build the sdist and wheel twice
# into separate temp dirs, compare sha256 digests, and fail on any
# mismatch. uv_build normalizes archive metadata and the stamp module
# is a pure function of the checked-out commit, so two builds of the
# same commit must hash identically.
[script]
build-repro-check: stamp
    out_a=$(mktemp -d)
    out_b=$(mktemp -d)
    trap 'rm -rf "$out_a" "$out_b"' EXIT
    SOURCE_DATE_EPOCH={{ source_date_epoch }} uv build --out-dir "$out_a"
    SOURCE_DATE_EPOCH={{ source_date_epoch }} uv build --out-dir "$out_b"
    for artifact in "$out_a"/*; do
        name=$(basename "$artifact")
        sum_a=$(shasum -a 256 < "$artifact")
        sum_b=$(shasum -a 256 < "$out_b/$name")
        if [[ "$sum_a" != "$sum_b" ]]; then
            echo "build not reproducible: $name differs between runs" >&2
            exit 1
        fi
    done

# Install the tool into uv's managed tool environment
install: stamp
    uv tool install --reinstall .

# Run the tool
run *args: stamp
    uv run proofhouse-python-tool "$@"

# Clean build artifacts
clean:
    rm -rf dist .pytest_cache .hypothesis htmlcov coverage.xml src/proofhouse_python_tool/_buildstamp.py
    rm -f .coverage .coverage.*

# --- Format ---

# Format Python code in place via ruff's formatter. `lint-ruff-format`
# runs the --check form, so formatting drift fails the gate instead of
# being rewritten behind the contributor's back.
format *args:
    uv run ruff format {{ args }}

# Format Markdown files (whitespace, list markers, code fence styles).
# Rewrites in place. Pair with `fix-markdown` for semantic lint fixes.
format-markdown *args:
    rumdl fmt {{ if args == "" { "." } else { args } }}

# Format JSON / JS / TS files in place via biome's formatter.
format-config *args:
    biome format --write {{ if args == "" { "." } else { args } }}

# --- Fix ---

# Fix Python lint findings: apply ruff's auto-fixes for the enabled
# ruleset, then run the formatter, since an applied fix can leave code
# shaped in ways the formatter would rewrite.
fix *args:
    uv run ruff check --fix {{ args }}
    uv run ruff format {{ args }}

# Apply rumdl's auto-fixable rules to Markdown files. Complement to
# `format-markdown` (which only rewrites whitespace and ordering, not
# semantic lints).
fix-markdown *args:
    rumdl check --fix {{ if args == "" { "." } else { args } }}

# --- Lint ---

# Aggregator over the Python-flavored lint gates. Carved out so the
# `lint` job in .github/workflows/ci.yml invokes a single recipe and
# stays untouched as new gates land; each new gate appends itself
# here. A pure dependency list with no logic of its own.
# `lint-workflows` rides along even though actionlint reads YAML, not
# Python: it belongs to the same per-PR gate set, in the spot where
# the Go repo's `lint-go-all` carries it.
lint-py-all: lint-ruff-format lint-ruff lint-types lint-complexity lint-deadcode lint-dup-code lint-imports lint-reuse lint-workflows

# Run every linter that operates on the source tree. Aggregator over
# the Python gates (via `lint-py-all`), prose (vale), spelling
# (cspell), Markdown (rumdl), config / JS / TS (biome), and YAML
# (yamllint).
lint: lint-py-all lint-prose lint-spelling lint-markdown lint-config lint-yaml

# Check Python formatting via ruff's formatter in --check mode: report
# drift and fail without rewriting anything. In a gate meant for CI,
# drift must fail the run, never rewrite the tree; `format` above is
# the in-place counterpart. The path-less invocation deliberately
# walks the whole tree, tests included — [tool.ruff]'s `src` setting
# names import-resolution roots, not the scan scope.
lint-ruff-format:
    uv run ruff format --check

# Lint Python code against the full ruff ruleset. Rule selection and
# the justified ignore list live in pyproject.toml under [tool.ruff].
# The path-less invocation deliberately walks the whole tree, tests
# included — [tool.ruff]'s `src` setting names import-resolution
# roots, not the scan scope.
lint-ruff *args:
    uv run ruff check {{ args }}

# Type check Python code with pyrefly. The [tool.pyrefly] tables in
# pyproject.toml pin every error kind to "error" and pick the project
# scope, so a bare project-mode check is the whole gate.
lint-types:
    uv run pyrefly check

# Measure per-function cognitive complexity with complexipy and fail
# on any function over the ceiling. Scope and threshold live in
# pyproject.toml under [tool.complexipy].
lint-complexity:
    uv run complexipy

# Find dead code with vulture. Scope lives in pyproject.toml under
# [tool.vulture], which also scans vulture_allowlist.py — the per-entry
# documented exemptions for names whose callers vulture cannot see
# (typer's decorator registration, the console-script entry in
# pyproject.toml).
lint-deadcode:
    uv run vulture

# Detect copy-pasted code with pylint, pared down in pyproject.toml's
# [tool.pylint] tables to its similarities checker alone — the one
# message in pylint's catalog no other tool in the chain covers.
# pylint takes its scan roots on the command line rather than from
# config, so this recipe is where the src-plus-tests scope lives.
lint-dup-code:
    uv run pylint src tests

# Enforce the architecture contracts in pyproject.toml's
# [tool.importlinter] tables: cli stays above buildmeta, and no
# production module imports the shipped testing helpers. The bare
# command is import-linter's own CLI, not this recipe recursing.
lint-imports:
    uv run lint-imports

# Verify SPDX compliance with reuse: every tracked file must declare
# copyright and license, either through the inline two-line header on
# Python sources or through a bulk annotation in REUSE.toml. The flag
# skips reuse's per-file process pool — on a tree this size the pool
# costs more to spawn than it saves, and the serial path also works
# in restricted environments that forbid the semaphores a pool needs.
lint-reuse:
    uv run reuse --no-multiprocessing lint

# Lint prose in Markdown files and source comments via vale. Glob
# excludes the LICENSE (canonical Apache 2.0 text), the auto-generated
# changelog, vale's own style packages, scratch dirs, the gitignored
# agent worktrees under .claude/worktrees/, the COMMIT_AGENTMSG draft
# (the `lint-commit-msg` recipe owns that one under the stricter
# commit scope), the virtualenv, build output, and the pytest and
# complexipy caches (each carries a generated README); the
# per-file-type rules in .vale.ini decide what else gets inspected.
lint-prose *args:
    vale --output=proofhouse-agent.tmpl --glob='!{LICENSE,CHANGELOG.md,.vale/*,tmp/*,.claude/worktrees/*,COMMIT_AGENTMSG,.venv/*,dist/*,.pytest_cache/*,.complexipy_cache/*}' {{ if args == "" { "." } else { args } }}

# Check spelling across the tree against the project dictionary at
# .cspell-words.txt. cspell ignores binaries, generated files, and the
# virtualenv via the ignorePaths block in .cspell.jsonc. The
# COMMIT_AGENTMSG draft gets excluded here and checked by
# `lint-commit-msg` instead, so a work-in-progress message never trips
# the tree-wide spell check.
lint-spelling *args:
    cspell --config .cspell.jsonc --no-summary --no-progress --no-must-find-files --exclude COMMIT_AGENTMSG {{ if args == "" { "." } else { args } }}

# Lint Markdown files against the project's .rumdl.toml ruleset.
# rumdl handles structural lints (heading style, list marker style,
# code fence style); vale handles prose.
lint-markdown *args:
    rumdl check {{ if args == "" { "." } else { args } }}

# Lint JSON / JS / TS files via biome. Recommended ruleset, biome's
# own formatter; covers config files (biome.json, .cspell.jsonc) and
# any future scripts under .github/actions/.
lint-config *args:
    biome check --files-ignore-unknown=true {{ if args == "" { "." } else { args } }}

# Lint YAML files (config, workflows, action definitions). --strict
# treats warnings as errors so the gate matches CI behavior; per-rule
# tuning lives in .yamllint.yaml.
lint-yaml *args:
    yamllint --strict {{ if args == "" { "." } else { args } }}

# Lint GitHub Actions workflow files via actionlint. actionlint walks
# `.github/workflows/` by default, parses each workflow, and flags
# unknown actions, mis-typed expressions, shellcheck issues inside
# `run:` blocks, and SHA-pin drift. Complements `lint-yaml` (which
# checks YAML structure) with workflow-shape rules yamllint can't see.
# Pinned Docker image; Renovate bumps the version + digest via the
# shared Justfile customManager.
lint-workflows:
    {{ actionlint }}

# Pre-validate a drafted commit message against the same gates the
# commit-msg hook runs, so message problems surface while iterating
# rather than at commit time. Reads the draft from the repo-root
# COMMIT_AGENTMSG file (gitignored; see AGENTS.md for the workflow) and
# runs the commit-msg stage through prek, which fires the four shared
# hooks from proofhouse/pre-commit-hooks: commit-trailers, commitlint,
# vale-commit-msg, and cspell-commit-msg. The real gate stays the prek
# commit-msg hook on .git/COMMIT_EDITMSG; this recipe only mirrors it.
# Commit the validated draft with `git commit -F COMMIT_AGENTMSG`.
lint-commit-msg:
    prek run --stage commit-msg --commit-msg-filename COMMIT_AGENTMSG

# --- Test ---

# Run tests. Serial by default so a failing run prints a clean,
# ordered trace; pass `just test -n auto` to fan the suite across
# xdist workers (one per core) when the wait outweighs the tidier
# output. pytest-randomly reshuffles the order every run and prints
# the seed it chose; reproduce a given order with
# `just test -p randomly --randomly-seed=N`.
test *args:
    uv run pytest "$@"

# Run the suite under coverage and enforce the branch-coverage floor.
# `--cov` with no value reads [tool.coverage.run]'s `source`, so the
# package — not the tests — is what gets measured; `--cov-branch` turns
# on branch tracking. The terminal report and the fail_under threshold
# both come from [tool.coverage.report]. This is the inner-loop recipe:
# run it, read the Missing column, write the test that reaches the gap.
cover:
    uv run pytest --cov --cov-branch

# Render the per-line HTML report under htmlcov/ and name the entry
# point. The source view shades each statement and each branch arm by
# whether a test reached it, which points at the exact line a new test
# still has to exercise.
cover-html:
    uv run pytest --cov --cov-branch
    uv run coverage html
    @echo "open htmlcov/index.html"

# Emit Cobertura XML from the data the last run left in .coverage.
# Cobertura is what diff-cover consumes and what the CI upload action
# publishes, so this recipe assumes a `cover` (or `cover-slot`) run
# already produced the data file.
cover-xml:
    uv run coverage xml -o coverage.xml

# Fail when any line changed since [base] lacks coverage. The whole-tree
# floor already sits at 100%, so on a clean branch this gate is
# redundant; it earns its place by catching a diff that drops coverage
# on touched lines before the slower combined total recomputes in CI.
# Reads coverage.xml, so run `cover-xml` first (CI does).
cover-diff base="origin/main":
    uv run diff-cover coverage.xml --compare-branch={{ base }} --fail-under=100

# Re-print the report and re-check the threshold against whatever data
# .coverage already holds, without rerunning the suite. Locally it
# re-checks after an exclude_also edit without paying for another run.
cover-check:
    uv run coverage report

# Combine every slot's data file into one .coverage, enforce the
# threshold against the merged total, and render the combined Cobertura.
# This is the authoritative gate: a branch that no single platform
# exercises still has to be reached by some slot, and the merged report
# is what proves it. The CI coverage job runs this after collecting the
# per-slot artifacts.
cover-combine:
    uv run coverage combine
    uv run coverage report --fail-under=100
    uv run coverage xml -o coverage.xml

# Capture one matrix slot's coverage into a uniquely named data file and
# render that slot's Cobertura XML. COVERAGE_FILE names the data file
# after the slot so the downstream job can combine every slot's data
# losslessly; --cov-fail-under=0 defers the threshold to that combined
# check, since one slot need not carry the whole package alone. The XML
# feeds the per-slot upload; CI passes the os/python pair as the slot.
# `-n auto` spreads the suite over one xdist worker per core, which a
# loaded CI runner gains the most from. pytest-cov writes a per-worker
# data file and merges them into this slot's COVERAGE_FILE on exit, so
# the figure stays whole-suite under the workers; relative_files keeps
# those merges portable for the cross-slot combine downstream.
[script]
cover-slot slot="local":
    export COVERAGE_FILE=".coverage.{{ slot }}"
    uv run pytest --cov --cov-branch --cov-fail-under=0 -n auto
    uv run coverage xml -o coverage.xml

# --- Security ---

# Hunt the working tree and every historical commit for leaked
# secrets. `gitleaks git` replays each commit's diff through the
# bundled regex and entropy detectors, so a credential that landed in
# an early commit and was later deleted still surfaces — a plain scan
# of the checked-out files would miss it. `--verbose` prints the file,
# line, commit, and rule behind each hit, enough to locate the leak
# without a second run. Brew provisions the binary (see Brewfile), and
# `brew upgrade gitleaks` advances the detector set with upstream.
#
# This gate is deliberately local-only: no ci.yml job mirrors it.
# GitHub's own secret scanning with push protection guards the remote
# side and refuses a push that introduces a known secret pattern, so a
# CI re-scan would duplicate a check the platform already enforces
# before the commit ever reaches a pull request.
gitleaks:
    gitleaks git --verbose .

# Roll the security scanners into one entry point a contributor can
# run before pushing. It holds only gitleaks today and gains the
# dependency-audit and SAST gates as those land, which keeps the
# scanner set named in one recipe rather than scattered across the
# Justfile. A bare dependency list, so a failure points straight at
# the scanner that fired.
security: gitleaks

# --- Dependencies ---

# Check that uv.lock is in sync with pyproject.toml. CI runs this on
# every PR; contributors run `uv lock` and commit the result.
lock-check:
    uv lock --check

# --- Utilities ---

# Sync Vale styles and dictionaries. Run once after cloning the repo,
# and whenever .vale.ini's Packages list changes. CI runs this before
# `just lint-prose`.
vale-sync:
    vale sync

# Run pre-commit hooks on changed files (the everyday invocation).
prek:
    prek

# Run pre-commit hooks on every file in the tree. Useful after a
# hook config change or before a release sweep.
prek-all:
    prek run --all-files

# Install the project's pre-commit hooks (commit-msg, pre-commit,
# pre-push). New contributors run this once after `just setup`; the
# `just setup` recipe does NOT run it automatically because installing
# hooks modifies .git/ and contributors may prefer to opt in.
prek-install:
    prek install -t commit-msg -t pre-commit -t pre-push

# Generate the full CHANGELOG.md from Conventional Commit history.
# `cog changelog` emits Markdown without an H1; the pipeline prepends
# one and runs rumdl with MD024 (duplicate headings) disabled so
# adjacent releases with the same section names don't fight the
# linter.
generate-changelog:
    cog changelog | { echo "# Changelog"; cat; } | rumdl check -d MD024 --fix --stdin > CHANGELOG.md

# Preview the changelog entries since the last tagged release. Useful
# during release prep to see what `cog changelog` will emit before
# committing the regeneration.
preview-changelog:
    cog changelog --at $(git describe --tags)..HEAD -t full_hash | rumdl check -d MD041 --fix --stdin

# Generate release notes for a specific version (or for HEAD if no
# version is given). Output goes to stdout; pipe to a file or paste
# into the GitHub release body.
[script]
generate-release-notes version="":
    v=$([[ -n "{{ version }}" ]] && echo "v{{ version }}" || echo "..$(git rev-parse HEAD)")
    cog changelog --at $v -t full_hash | rumdl check -d MD024,MD041 --isolated --fix --stdin
