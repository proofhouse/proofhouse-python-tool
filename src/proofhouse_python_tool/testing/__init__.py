# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Helpers for test suites that exercise the CLI in-process.

This subpackage ships with the distribution and is public API:
downstream test suites build on these helpers instead of wiring up
their own click runner against the app object.
"""

from collections.abc import Sequence

from typer.testing import CliRunner, Result

from proofhouse_python_tool.cli import app


def runner() -> CliRunner:
    """Return a CliRunner set up for the proofhouse-python-tool app."""
    return CliRunner()


def invoke(args: Sequence[str]) -> Result:
    """Run the CLI in-process with the given arguments."""
    return runner().invoke(app, args)
