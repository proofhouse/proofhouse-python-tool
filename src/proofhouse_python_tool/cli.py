# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Command-line surface of the Proofhouse Python tool.

The CLI stays intentionally minimal; its purpose: give the surrounding
gates something to build and ship through the release pipeline. The
repository's value sits in the supply chain plumbing around the tool,
not in the tool's own command surface.
"""

import typer

from proofhouse_python_tool import buildmeta

app = typer.Typer(no_args_is_help=True, add_completion=False)


@app.callback()
def _root() -> None:
    """Reference CLI for the Proofhouse Python tool reference repository."""


@app.command()
def version() -> None:
    """Print version, commit, and build date."""
    info = buildmeta.get()
    typer.echo(
        f"proofhouse-python-tool {info.version}\n"
        f"commit: {info.commit}\n"
        f"date:   {info.date}"
    )


def main() -> None:
    """Run the app. The console-script entry point targets this function."""
    app()
