# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Compute the mutation scope for a diff and emit a scoped cosmic-ray config.

The diff-scoped mutation gate runs cosmic-ray over only the modules a pull
request can have changed the behavior of: the first-party modules touched by
the diff plus every first-party module that transitively imports one of them.
An importer inherits the behavioral assumptions of what it imports, so a
change two layers down can leave an importer's tests passing on stale logic
that a mutant would expose.

This script maps the changed ``src`` files to module names, walks the package
import graph with grimp to add the downstream importers, turns that set back
into source-file paths, and writes a cosmic-ray config derived from the
canonical ``cosmic-ray.toml`` with ``module-path`` narrowed to exactly that
set. An empty diff (no first-party source change) yields an empty scope and a
config that mutates nothing, which the gate treats as a clean pass.

A second mode (``--count-survivors``) reads a ``cosmic-ray dump`` stream on
stdin and prints how many mutants survived, the figure the gate fails on. It
lives here rather than as an inline shell snippet so the JSON walk is held to
the same lint and type gates as the scope logic.
"""

import json
import subprocess
import sys
from pathlib import Path

import grimp
from cosmic_ray.config import load_config, serialize_config

PACKAGE = "proofhouse_python_tool"
SRC_ROOT = Path("src")
PACKAGE_ROOT = SRC_ROOT / PACKAGE
BASE_CONFIG = Path("cosmic-ray.toml")


def _changed_files(base: str) -> list[Path]:
    """Return the paths git reports changed between ``base`` and HEAD.

    The three-dot diff form compares against the merge base, so commits that
    landed on the base branch after this branch forked don't count as changes
    of this branch.
    """
    out = subprocess.run(  # noqa: S603
        ["git", "diff", "--name-only", f"{base}...HEAD"],  # noqa: S607
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return [Path(line) for line in out.splitlines() if line]


def _module_name(path: Path) -> str | None:
    """Map a repository path to its module name, or None when it names no module.

    Only ``.py`` files under the package root map to modules. An ``__init__``
    file names its package directory rather than a submodule.
    """
    if path.suffix != ".py" or PACKAGE_ROOT not in path.parents:
        return None
    relative = path.relative_to(SRC_ROOT)
    parts = relative.with_suffix("").parts
    if parts[-1] == "__init__":
        parts = parts[:-1]
    return ".".join(parts)


def _module_path(module: str) -> Path:
    """Map a module name back to its source path under ``src``.

    A package (a name with no module file of its own) resolves to its
    ``__init__`` file. A leaf module resolves to the matching ``.py``.
    """
    base = SRC_ROOT.joinpath(*module.split("."))
    return base / "__init__.py" if base.is_dir() else base.with_suffix(".py")


def compute_scope(base: str) -> set[str]:
    """Return the changed first-party modules plus their downstream importers.

    A changed module absent from the import graph (a new file nothing imports
    yet) still enters the scope on its own. Only the downstream walk needs the
    module to be a graph node.
    """
    changed = {
        name
        for path in _changed_files(base)
        if (name := _module_name(path)) is not None
    }
    if not changed:
        return set()
    graph = grimp.build_graph(PACKAGE)
    scope: set[str] = set()
    for module in changed:
        scope.add(module)
        if module in graph.modules:
            scope.update(graph.find_downstream_modules(module))
    return scope


def write_config(scope: set[str], destination: Path) -> None:
    """Write a cosmic-ray config scoped to ``scope`` derived from the base file.

    Loading and re-serializing through cosmic-ray's own config machinery keeps
    the excluded-modules list, the test command, and the distributor identical
    to the canonical config. Only ``module-path`` narrows to the scoped files.
    """
    config = load_config(str(BASE_CONFIG))
    config["module-path"] = sorted(str(_module_path(m)) for m in scope)
    destination.write_text(serialize_config(config), encoding="utf-8")


def count_survivors(dump: str) -> int:
    """Count the surviving mutants in a ``cosmic-ray dump`` stream.

    Each line is a ``[work-item, result]`` pair. A missing result means the
    job never completed, which the gate should never see after a full exec but
    counts as not-survived rather than crashing the walk.
    """
    survivors = 0
    for line in dump.splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        result = record[1] if len(record) > 1 else None
        if result is not None and result.get("test_outcome") == "survived":
            survivors += 1
    return survivors


def _emit_scope(destination: Path, base: str) -> None:
    """Compute the scope for ``base`` and write the scoped config.

    The scoped module set goes to stderr so the run log records exactly what
    the gate mutated, never a silent empty scope.
    """
    scope = compute_scope(base)
    write_config(scope, destination)
    if scope:
        listing = " ".join(sorted(scope))
        print(f"mutation scope ({len(scope)} modules): {listing}", file=sys.stderr)
    else:
        print("mutation scope: empty (no first-party source change)", file=sys.stderr)


def main() -> None:
    """Dispatch the two modes the diff-mutation recipe drives.

    A config path argument selects the scope-writing mode, with an optional
    base ref that defaults to ``origin/main``. The survivor-count flag instead
    reads a ``cosmic-ray dump`` on stdin and prints how many mutants lived.
    """
    if sys.argv[1] == "--count-survivors":
        print(count_survivors(sys.stdin.read()))
        return
    destination = Path(sys.argv[1])
    base = sys.argv[2] if len(sys.argv) > 2 else "origin/main"
    _emit_scope(destination, base)


if __name__ == "__main__":
    main()
