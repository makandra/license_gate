## Unreleased

- Checks the licenses of npm packages installed through Yarn; Yarn 2 and later need the plugin yarn-plugin-licenses.

## [0.1.0] - 2026-11-18

- Checks the licenses of Bundler gems and pnpm packages.
- Reads configuration from `config/license_gate.yml` by default.
- Allows specifying configuration file location through `--config` CLI option.
- Lists all packages with their licenses through `--report` CLI option.
