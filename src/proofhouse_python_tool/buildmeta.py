# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Build-time information stamped into the tool.

The version comes from the installed distribution metadata. Commit and date
come from the generated ``_buildstamp`` module the Justfile stamp recipe
writes next to this one; each field falls back to a placeholder when the tool
runs straight from an unstamped source checkout.
"""

from dataclasses import dataclass
from importlib import import_module, metadata


@dataclass(frozen=True)
class BuildInfo:
    """Version, short git SHA, and calendar build date of a tool build."""

    version: str
    commit: str
    date: str


def get() -> BuildInfo:
    """Return the current build metadata."""
    try:
        version = metadata.version("proofhouse-python-tool")
    except metadata.PackageNotFoundError:
        version = "dev"
    try:
        stamp = import_module("proofhouse_python_tool._buildstamp")
    except ImportError:
        return BuildInfo(version=version, commit="", date="unknown")
    return BuildInfo(version=version, commit=stamp.COMMIT, date=stamp.DATE)
