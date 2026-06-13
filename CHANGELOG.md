# Changelog

## [v0.1.0](https://github.com/proofhouse/proofhouse-python-tool/compare/ab026a0c078720a5d8d715d2421ed2effcb57c4e..v0.1.0) - 2026-06-13

### Features

- add proofhouse-python-tool CLI with version subcommand - ([ce0c24e](https://github.com/proofhouse/proofhouse-python-tool/commit/ce0c24e6e7bc29eef00c08a5d75d0fdbac8ed590)) - [@tbhb](https://github.com/tbhb)
- add buildmeta with version, commit, and date stamping - ([cad1c38](https://github.com/proofhouse/proofhouse-python-tool/commit/cad1c3889469617ddacc4ac7dc8a2508dd6afe09)) - [@tbhb](https://github.com/tbhb)
- add pyproject.toml with uv_build backend - ([536876a](https://github.com/proofhouse/proofhouse-python-tool/commit/536876a858c7874404936f9a92f1e0ea328fd956)) - [@tbhb](https://github.com/tbhb)

#### Documentation

- add agent instructions and worktree rules - ([5f2673c](https://github.com/proofhouse/proofhouse-python-tool/commit/5f2673cb9b30cf018ee7ccf672c03646cc038441)) - [@tbhb](https://github.com/tbhb)

#### Build system

- (**deps**) commit uv.lock and add lock-check drift gate - ([09383b2](https://github.com/proofhouse/proofhouse-python-tool/commit/09383b254c60feae6e991a398a987cacff0a2fef)) - [@tbhb](https://github.com/tbhb)
- make wheel builds reproducible - ([8739722](https://github.com/proofhouse/proofhouse-python-tool/commit/873972291f9345d508719fad65b1bbc6c16b8fb0)) - [@tbhb](https://github.com/tbhb)
- add minimal Justfile with build, run, and test recipes - ([b89f0d5](https://github.com/proofhouse/proofhouse-python-tool/commit/b89f0d5511c5fe91122e585d1751f177c4b4e33f)) - [@tbhb](https://github.com/tbhb)

#### Continuous Integration

- (**actions**) add CodeQL scanning for Python and Actions (#19) - ([d6f33f3](https://github.com/proofhouse/proofhouse-python-tool/commit/d6f33f3f57543f44c481b7fdc430275d8b465840)) - [@tbhb](https://github.com/tbhb)
- (**actions**) add security.yml with OSV-Scanner SARIF uploads (#18) - ([ac97de9](https://github.com/proofhouse/proofhouse-python-tool/commit/ac97de9ac6face54600a12fef0195432d32a4482)) - [@tbhb](https://github.com/tbhb)
- (**actions**) consume shared lint-workflows and lint-codeowners workflows - ([04079f4](https://github.com/proofhouse/proofhouse-python-tool/commit/04079f4bfc7c3cfaa17ed4fea4bb5eb8676e991a)) - [@tbhb](https://github.com/tbhb)
- (**actions**) add ci.yml with matrixed test and lock-check jobs - ([5bc31c3](https://github.com/proofhouse/proofhouse-python-tool/commit/5bc31c392fa9f0e503514ef1227e3b138793d7f4)) - [@tbhb](https://github.com/tbhb)
- add bandit security gate (#17) - ([dcf4edc](https://github.com/proofhouse/proofhouse-python-tool/commit/dcf4edc1cad5aebca2d36b879142a64666d9a905)) - [@tbhb](https://github.com/tbhb)
- add pip-audit dependency vulnerability gate (#16) - ([f7b00c1](https://github.com/proofhouse/proofhouse-python-tool/commit/f7b00c17c76505fe0282963b8ab4412df55c2c5b)) - [@tbhb](https://github.com/tbhb)
- default vale output to the agent template - ([f3f8310](https://github.com/proofhouse/proofhouse-python-tool/commit/f3f8310f76ff5dd5bab8b5e5ac3cf55130f7fd5c)) - [@tbhb](https://github.com/tbhb)
- adopt the shared proofhouse vale package - ([a9efa1b](https://github.com/proofhouse/proofhouse-python-tool/commit/a9efa1b72d97491ebdae848fc671800e620bf04c)) - [@tbhb](https://github.com/tbhb)
- add gitleaks secret scanning (#15) - ([6884bd7](https://github.com/proofhouse/proofhouse-python-tool/commit/6884bd7c69e9b8013a19cd76aa9eeaa4dc63e43e)) - [@tbhb](https://github.com/tbhb)
- add lint aggregators across the toolchain (#11) - ([d2b670e](https://github.com/proofhouse/proofhouse-python-tool/commit/d2b670ec079ef38db553bf91b3b8e2ab65e9a823)) - [@tbhb](https://github.com/tbhb)
- add reuse SPDX compliance gate (#10) - ([9fb026b](https://github.com/proofhouse/proofhouse-python-tool/commit/9fb026b86afbb2c48346a7ab63a335496260f3d5)) - [@tbhb](https://github.com/tbhb)
- add import-linter architecture contracts (#6) - ([7ce2dfe](https://github.com/proofhouse/proofhouse-python-tool/commit/7ce2dfec6799b760f55ffd401552db0e7e13f880)) - [@tbhb](https://github.com/tbhb)
- add pylint duplicate-code gate (#5) - ([b9f0908](https://github.com/proofhouse/proofhouse-python-tool/commit/b9f09082abc7d688504e83ed7335da75e07928a2)) - [@tbhb](https://github.com/tbhb)
- add vulture dead code gate (#4) - ([442f5f6](https://github.com/proofhouse/proofhouse-python-tool/commit/442f5f688cf4ca36fd609a43e1435d58114fa0cc)) - [@tbhb](https://github.com/tbhb)
- add complexipy cognitive complexity gate (#3) - ([0f1c20f](https://github.com/proofhouse/proofhouse-python-tool/commit/0f1c20f1932315a62417ca712aa6c0c90a440386)) - [@tbhb](https://github.com/tbhb)
- add pyrefly strict type checking gate (#2) - ([1f22cab](https://github.com/proofhouse/proofhouse-python-tool/commit/1f22cab84763eabe049b491c1d1379fb6518aa7c)) - [@tbhb](https://github.com/tbhb)
- wire ruff format and lint with the full ruleset (#1) - ([56590c2](https://github.com/proofhouse/proofhouse-python-tool/commit/56590c2e58bfdf92bdf2936938f6ab8b913f0639)) - [@tbhb](https://github.com/tbhb)
- add self-hosted Renovate config and workflows - ([18d89a3](https://github.com/proofhouse/proofhouse-python-tool/commit/18d89a350bba15cfdf7cd171e8e1fb0e4bd793fc)) - [@tbhb](https://github.com/tbhb)
- adopt prek with builtin hooks and shared commit-msg gates - ([320fab7](https://github.com/proofhouse/proofhouse-python-tool/commit/320fab75bc848816e4e8c22aee71c76c2ee91697)) - [@tbhb](https://github.com/tbhb)
- add yamllint for YAML linting - ([34a7aca](https://github.com/proofhouse/proofhouse-python-tool/commit/34a7acaa85c8bb66287e242bd710162187f0b25c)) - [@tbhb](https://github.com/tbhb)
- add biome for JSON linting and formatting - ([c175af9](https://github.com/proofhouse/proofhouse-python-tool/commit/c175af949336e53beb5bfe34e1200ed13cdd5218)) - [@tbhb](https://github.com/tbhb)
- add rumdl markdown linter - ([6d83aee](https://github.com/proofhouse/proofhouse-python-tool/commit/6d83aee82cc2c401738cbd88eba277ba55a9fed6)) - [@tbhb](https://github.com/tbhb)
- add cspell spelling checker with project dictionary - ([27dd9b1](https://github.com/proofhouse/proofhouse-python-tool/commit/27dd9b1ea24c230e1113051cdff0534b396c1d85)) - [@tbhb](https://github.com/tbhb)
- add vale prose linter with proofhouse styles and vocabulary - ([a3364df](https://github.com/proofhouse/proofhouse-python-tool/commit/a3364dfe7426f5583de885549860aeb269907031)) - [@tbhb](https://github.com/tbhb)

#### Style

- keep the SPDX tag out of a vale comment - ([8f4b6bf](https://github.com/proofhouse/proofhouse-python-tool/commit/8f4b6bfd038c874268f682e763b8b0e8cbf060c3)) - [@tbhb](https://github.com/tbhb)
- apply vale fixes to existing tree - ([9eab5d9](https://github.com/proofhouse/proofhouse-python-tool/commit/9eab5d9298e8af3b23f3971b7bd1978dcc5f2191)) - [@tbhb](https://github.com/tbhb)
