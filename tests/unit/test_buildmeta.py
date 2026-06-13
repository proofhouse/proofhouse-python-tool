# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Tests for the buildmeta fallback and stamped paths."""

import dataclasses
import sys
from importlib import metadata
from types import ModuleType

import pytest

from proofhouse_python_tool import buildmeta

_STAMP_MODULE = "proofhouse_python_tool._buildstamp"


class _FakeStamp(ModuleType):
    """Stand-in for the module the Justfile stamp recipe generates."""

    def __init__(self, commit: str, date: str) -> None:
        super().__init__(_STAMP_MODULE)
        self.COMMIT = commit
        self.DATE = date


def _missing_version(distribution: str) -> str:
    raise metadata.PackageNotFoundError(distribution)


def _pinned_version(distribution: str) -> str:
    assert distribution == "proofhouse-python-tool"
    return "1.2.3"


def test_get_falls_back_when_uninstalled_and_unstamped(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(metadata, "version", _missing_version)
    # A None entry makes the import machinery raise ImportError, masking any
    # locally generated stamp file.
    monkeypatch.setitem(sys.modules, _STAMP_MODULE, None)
    assert buildmeta.get() == buildmeta.BuildInfo(
        version="dev", commit="", date="unknown"
    )


def test_get_reads_distribution_version_and_stamp(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(metadata, "version", _pinned_version)
    monkeypatch.setitem(
        sys.modules, _STAMP_MODULE, _FakeStamp(commit="abc1234", date="2026-06-11")
    )
    assert buildmeta.get() == buildmeta.BuildInfo(
        version="1.2.3", commit="abc1234", date="2026-06-11"
    )


def test_build_info_is_immutable() -> None:
    # The stamp is read once and rendered as-is. A writable BuildInfo would
    # let a caller silently rewrite the reported build, so the frozen flag
    # is part of the contract, not an incidental default.
    info = buildmeta.BuildInfo(version="1.2.3", commit="abc1234", date="2026-06-11")
    with pytest.raises(dataclasses.FrozenInstanceError):
        info.version = "9.9.9"  # type: ignore[misc]
