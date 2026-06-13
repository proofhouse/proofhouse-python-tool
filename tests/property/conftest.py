# SPDX-License-Identifier: Apache-2.0
# Copyright Authors of Proofhouse

"""Hypothesis profile registration for the property suites.

This conftest sits beside the property tests rather than at the tests/
root, so the example counts and the deadline govern only the suites
that draw from hypothesis. The unit tests next door run no slower for
it. HYPOTHESIS_PROFILE picks the active profile and falls back to dev.
"""

import os

from hypothesis import settings

# The inner-loop profile: enough examples to surface an obvious
# counterexample fast, few enough to keep `just test` snappy.
settings.register_profile("dev", max_examples=50)

# The CI profile draws ten times as many examples under no per-example
# deadline. A loaded shared runner lags a developer's machine, so a
# deadline trip there reads as noise rather than a real regression.
settings.register_profile("ci", max_examples=500, deadline=None)

settings.load_profile(os.environ.get("HYPOTHESIS_PROFILE", "dev"))
