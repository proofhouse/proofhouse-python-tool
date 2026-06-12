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
    uv build

# Install the tool into uv's managed tool environment
install: stamp
    uv tool install --reinstall .

# Run the tool
run *args: stamp
    uv run proofhouse-python-tool "$@"

# Clean build artifacts
clean:
    rm -rf dist .pytest_cache src/proofhouse_python_tool/_buildstamp.py

# --- Test ---

# Run tests
test *args:
    uv run pytest "$@"
