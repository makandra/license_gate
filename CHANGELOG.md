## Unreleased

- Checks the licenses of npm packages installed through Yarn Classic (1) and Yarn 4; Yarn 4 needs the plugin yarn-plugin-licenses.
- Fails when a project has lockfiles of several package managers, e.g. a `pnpm-lock.yaml` and a `yarn.lock`.

## [0.1.0] - 2026-11-18

- Checks the licenses of Bundler gems and pnpm packages.
- Reads configuration from `config/license_gate.yml` by default.
- Allows specifying configuration file location through `--config` CLI option.
- Lists all packages with their licenses through `--report` CLI option.
