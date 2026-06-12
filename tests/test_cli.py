# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Tests for the CLI command surface."""

import re

import pytest
from typer.testing import CliRunner

from proofhouse_python_tool import buildmeta, cli

_runner = CliRunner()

# Three lines, prefixes aligned as in the Go twin; the commit field may
# remain empty on an unstamped source checkout.
_VERSION_SHAPE = re.compile(
    r"proofhouse-python-tool [^\n]+\n"
    r"commit: [^\n]*\n"
    r"date:   [^\n]+\n"
)


def _stamped_get() -> buildmeta.BuildInfo:
    return buildmeta.BuildInfo(version="1.2.3", commit="abc1234", date="2026-06-11")


def test_version_exits_zero_and_matches_shape() -> None:
    result = _runner.invoke(cli.app, ["version"])
    assert result.exit_code == 0
    assert _VERSION_SHAPE.fullmatch(result.output)


def test_version_prints_stamped_build_info(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(buildmeta, "get", _stamped_get)
    result = _runner.invoke(cli.app, ["version"])
    assert result.exit_code == 0
    assert result.output == (
        "proofhouse-python-tool 1.2.3\ncommit: abc1234\ndate:   2026-06-11\n"
    )


def test_bare_invocation_shows_help() -> None:
    result = _runner.invoke(cli.app, [])
    assert result.exit_code == 2
    assert "Usage:" in result.output
    assert (
        "Reference CLI for the Proofhouse Python tool reference repository."
        in result.output
    )
    assert "version" in result.output
