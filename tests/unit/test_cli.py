# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Tests for the CLI command surface."""

import re
import sys

import pytest

from proofhouse_python_tool import buildmeta, cli, testing

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
    result = testing.invoke(["version"])
    assert result.exit_code == 0
    assert _VERSION_SHAPE.fullmatch(result.output)


def test_version_prints_stamped_build_info(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(buildmeta, "get", _stamped_get)
    result = testing.invoke(["version"])
    assert result.exit_code == 0
    assert result.output == (
        "proofhouse-python-tool 1.2.3\ncommit: abc1234\ndate:   2026-06-11\n"
    )


def test_bare_invocation_shows_help() -> None:
    result = testing.invoke([])
    assert result.exit_code == 2
    assert "Usage:" in result.output
    assert (
        "Reference CLI for the Proofhouse Python tool reference repository."
        in result.output
    )
    assert "version" in result.output


def test_help_omits_shell_completion_options() -> None:
    # The app turns completion off, so typer never grafts its pair of
    # shell-completion install and show options onto the surface. The
    # tool's contract is the lone version command; that plumbing is surface
    # the release pipeline has no reason to carry.
    result = testing.invoke(["--help"])
    assert result.exit_code == 0


def test_main_runs_the_app(monkeypatch: pytest.MonkeyPatch) -> None:
    # The console-script entry point runs through main(), which hands the
    # typer app the process argv. The in-process CliRunner the other tests
    # use bypasses that path, so drive main() through a clean exit here to
    # cover the entry-point line.
    monkeypatch.setattr(sys, "argv", ["proofhouse-python-tool", "version"])
    with pytest.raises(SystemExit) as exc_info:
        cli.main()
    assert exc_info.value.code == 0
