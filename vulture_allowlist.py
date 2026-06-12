# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

# Vulture allowlist. [tool.vulture] scans this file alongside src and
# tests, so a bare name here counts as a use of the definition vulture
# would otherwise flag. Nothing imports this file. Each entry explains
# where the real caller hides from vulture's static view.

# typer runs the root callback through its @app.callback()
# registration, and nothing ever refers to the function by name.
_root

# The console-script entry point declared in pyproject.toml targets
# cli.main, so the only caller lives in packaging metadata rather than
# in Python source.
main
