# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Property suites for the build metadata and its CLI rendering.

The unit tests pin a handful of concrete stamps; these widen the input
to every single-line value a stamp can hold and assert the invariants
that have to survive all of them.
"""

import sys
from importlib import metadata
from types import ModuleType
from unittest import mock

from hypothesis import given
from hypothesis import strategies as st

from proofhouse_python_tool import buildmeta, testing

_STAMP_MODULE = "proofhouse_python_tool._buildstamp"

# The three-line version block: the distribution name and version, then
# the commit and date under aligned prefixes. The commit line tolerates
# a blank value (an unstamped checkout). The version and date never run
# blank.
_VERSION_SHAPE = (
    "proofhouse-python-tool {info.version}\n"
    "commit: {info.commit}\n"
    "date:   {info.date}\n"
)


@given(info=testing.stamp_values())
def test_version_renders_three_lines_for_any_stamp(
    info: buildmeta.BuildInfo,
) -> None:
    """The version command echoes any stamp as the same three-line block."""
    with mock.patch.object(buildmeta, "get", return_value=info):
        result = testing.invoke(["version"])
    assert result.exit_code == 0
    assert result.output == _VERSION_SHAPE.format(info=info)


class _FakeStamp(ModuleType):
    """Stand-in for the module the Justfile stamp recipe generates."""

    def __init__(self, commit: str, date: str) -> None:
        super().__init__(_STAMP_MODULE)
        self.COMMIT = commit
        self.DATE = date


@given(
    version=st.text(min_size=1),
    commit=st.text(),
    date=st.text(),
    stamped=st.booleans(),
)
def test_get_reflects_stamp_presence(
    version: str,
    commit: str,
    date: str,
    *,
    stamped: bool,
) -> None:
    """get() reads a present stamp and falls back when one goes missing.

    With the stamp module importable, get() reports the commit and date
    it carries. With the import blocked, get() falls back to the empty
    commit and the "unknown" date, whatever a stale stamp file on disk
    happens to hold.
    """
    stamp = _FakeStamp(commit, date) if stamped else None
    with (
        mock.patch.object(metadata, "version", return_value=version),
        mock.patch.dict(sys.modules, {_STAMP_MODULE: stamp}),
    ):
        info = buildmeta.get()
    if stamped:
        assert info == buildmeta.BuildInfo(version, commit, date)
    else:
        assert info == buildmeta.BuildInfo(version, "", "unknown")
