# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Helpers for test suites that exercise the CLI in-process.

This subpackage ships with the distribution and is public API:
downstream test suites build on these helpers instead of wiring up
their own click runner against the app object, and the strategies
below feed the property suites that drive that runner.
"""

from collections.abc import Sequence

from hypothesis import strategies as st
from typer.testing import CliRunner, Result

from proofhouse_python_tool.buildmeta import BuildInfo
from proofhouse_python_tool.cli import app


def runner() -> CliRunner:
    """Return a CliRunner set up for the proofhouse-python-tool app."""
    return CliRunner()


def invoke(args: Sequence[str]) -> Result:
    """Run the CLI in-process with the given arguments."""
    return runner().invoke(app, args)


# Each build-stamp field spans one line of free text: the version comes
# from distribution metadata, the commit and date from the generated
# stamp module. Dropping the newline and carriage return keeps a drawn
# value on a single output line, which the version command's three-line
# shape depends on. Restricting to characters that encode as utf-8 rules
# out lone surrogates, which the command could never echo through its
# utf-8 stdout anyway. Version and date carry at least one character,
# since the command always prints something after their prefixes; the
# commit can stay blank on an unstamped checkout.
_field = st.text(
    st.characters(codec="utf-8", exclude_characters="\n\r"),
    min_size=1,
)


def stamp_values() -> st.SearchStrategy[BuildInfo]:
    """Generate the version, commit, and date a build stamp can report.

    The commit can come back empty, since an unstamped source checkout
    reports no SHA. Version and date always carry a value.
    """
    return st.builds(
        BuildInfo,
        version=_field,
        commit=st.one_of(st.just(""), _field),
        date=_field,
    )
