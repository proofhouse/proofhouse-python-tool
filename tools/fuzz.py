# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Run HypoFuzz over the property suite for a capped stretch, then judge it.

`hypothesis fuzz` is a coverage-guided loop with no stop condition of its own:
it keeps steering inputs toward fresh branches until something interrupts it,
or until every target has already failed. That open-ended shape never gates on
its own, so this driver bolts a clock onto it. It launches the search, lets it
run for the FUZZ_TIME budget, and then interrupts it.

Whether the budget found a bug is a separate question from whether the search
finished. HypoFuzz banks any falsifying input into the shared `.hypothesis`
database as soon as it lands, so the verdict comes from replaying the property
suite under plain pytest afterward. That replay reads the same database, reruns
whatever counterexample the search saved, and exits non-zero when one of them
reproduces. The driver forwards that exit code, so a crasher fails the run even
if the search was mid-flight when the clock ran out.

FUZZ_TIME is a count of seconds or a number suffixed `s`, `m`, or `h`, the same
dial the Go twin's fuzz recipe accepts so both lanes reason about the budget the
same way. The edit-rerun loop runs a brief default; the nightly hands in a much
wider one.
"""

import os
import signal
import subprocess
import time

PROPERTY_SUITE = "tests/property"
DEFAULT_BUDGET = "30"
# HypoFuzz forks a worker pool, so the driver gives the whole group time to
# flush the database and retire its workers after the interrupt before it
# resorts to a forced stop.
SHUTDOWN_GRACE_SECONDS = 20.0
_UNIT_SECONDS = {"s": 1, "m": 60, "h": 3600}


def parse_budget(raw: str) -> float:
    """Turn a duration or a bare seconds count into a float of seconds.

    A trailing ``s``, ``m``, or ``h`` scales the leading number; a number with
    no suffix is already in seconds. A value that won't parse, or a result
    that isn't positive, aborts the run instead of falling back silently and
    masking a fat-fingered budget.
    """
    text = raw.strip()
    unit = _UNIT_SECONDS.get(text[-1:])
    number = text[:-1] if unit is not None else text
    try:
        seconds = float(number) * (unit if unit is not None else 1)
    except ValueError:
        message = f"could not read FUZZ_TIME {raw!r}: want seconds or a duration"
        raise SystemExit(message) from None
    if seconds <= 0:
        message = f"FUZZ_TIME must be positive, got {raw!r}"
        raise SystemExit(message)
    return seconds


def run_fuzzer(budget: float) -> None:
    """Fuzz the property suite for ``budget`` seconds, then wind the search down.

    The search runs as a child in its own process group so the budget is
    enforced from here and the interrupt reaches every worker HypoFuzz forked.
    Signaling the parent alone would orphan the pool and hang the wait. Once
    the clock elapses the group gets SIGINT, the clean-stop signal HypoFuzz
    honors. A grace window then lets its findings flush before a forced stop.
    A child that exits early (all targets already failed) is left be.
    """
    command = [
        "uv",
        "run",
        "hypothesis",
        "fuzz",
        "--no-dashboard",
        "--",
        PROPERTY_SUITE,
    ]
    proc = subprocess.Popen(command, start_new_session=True)  # noqa: S603
    group = os.getpgid(proc.pid)
    deadline = time.monotonic() + budget
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            return
        time.sleep(1)
    os.killpg(group, signal.SIGINT)
    try:
        proc.wait(timeout=SHUTDOWN_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        os.killpg(group, signal.SIGKILL)
        proc.wait()


def replay_suite() -> int:
    """Replay the property suite under pytest and hand back its exit code.

    Pytest reads the same ``.hypothesis`` database HypoFuzz just populated, so
    any counterexample the search banked replays here and fails. A search that
    turned up nothing leaves the database without a new example to reproduce,
    and this pass comes back green.
    """
    return subprocess.run(  # noqa: S603
        ["uv", "run", "pytest", PROPERTY_SUITE],  # noqa: S607
        check=False,
    ).returncode


def main() -> None:
    """Fuzz for the FUZZ_TIME budget, then exit on the replay's verdict."""
    budget = parse_budget(os.environ.get("FUZZ_TIME", DEFAULT_BUDGET))
    run_fuzzer(budget)
    raise SystemExit(replay_suite())


if __name__ == "__main__":
    main()
