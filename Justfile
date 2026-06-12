set unstable := true
set positional-arguments := true

# Run [script] recipes under bash rather than the default sh. On Linux
# sh is dash, which lacks [[ ]], <<<, and set -o pipefail — constructs
# [script] recipes are free to rely on. macOS sh is bash, so a dash
# incompatibility would stay hidden locally until CI runs on Linux.
set script-interpreter := ['bash', '-eu']

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
    rm -rf dist .pytest_cache src/proofhouse_python_tool/_buildstamp.py

# --- Format ---

# Format Markdown files (whitespace, list markers, code fence styles).
# Rewrites in place. Pair with `fix-markdown` for semantic lint fixes.
format-markdown *args:
    rumdl fmt {{ if args == "" { "." } else { args } }}

# Format JSON / JS / TS files in place via biome's formatter.
format-config *args:
    biome format --write {{ if args == "" { "." } else { args } }}

# --- Fix ---

# Apply rumdl's auto-fixable rules to Markdown files. Complement to
# `format-markdown` (which only rewrites whitespace and ordering, not
# semantic lints).
fix-markdown *args:
    rumdl check --fix {{ if args == "" { "." } else { args } }}

# --- Lint ---

# Lint prose in Markdown files and source comments via vale. Glob
# excludes the LICENSE (canonical Apache 2.0 text), the auto-generated
# changelog, vale's own style packages, scratch dirs, the gitignored
# agent worktrees under .claude/worktrees/, the COMMIT_AGENTMSG draft
# (the `lint-commit-msg` recipe owns that one under the stricter
# commit scope), the virtualenv, build output, and the pytest cache
# (it carries a generated README); the per-file-type rules in
# .vale.ini decide what else gets inspected.
lint-prose *args:
    vale --glob='!{LICENSE,CHANGELOG.md,.vale/*,tmp/*,.claude/worktrees/*,COMMIT_AGENTMSG,.venv/*,dist/*,.pytest_cache/*}' {{ if args == "" { "." } else { args } }}

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

# --- Test ---

# Run tests
test *args:
    uv run pytest "$@"

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
