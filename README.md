# License Gate

`license_gate` checks licenses of your project's dependencies against a configuration in your repository.
It covers gems of your [Bundler](https://bundler.io/) Gemfile and npm packages installed through [pnpm](https://pnpm.io/) or [Yarn](https://yarnpkg.com/).

License Gate works with an allowlist: any license your configuration does not permit fails the check.
If you accept some licenses only for specific packages, those can be specified as well.


## Installation

Add the gem to your Gemfile, e.g. in development and test groups:

```ruby
group :development, :test do
  gem 'license_gate'
end
```


## Usage

Run the CLI command from your project:

```
bundle exec license_gate
```

It always checks your gems, and npm packages when there is a `pnpm-lock.yaml` or `yarn.lock`.
When packages use licenses that are not permitted, it lists them and fails:

```
$ bundle exec license_gate
✗ gem some-gem 1.2.0: GPL-3.0-only
✗ npm some-package 0.4.0: Unknown (no license found)

2 of 123 packages use licenses that are not permitted.
Permit a license in config/license_gate.yml, or add a license exception with a reason.
```

When all licenses are permitted, it prints `All 123 packages use permitted licenses (23 gems, 100 npm packages).`

Configuration is read from `config/license_gate.yml`, or from a file passed as `--config PATH`.
A configuration file must exist in your project. See below for an example.

Run License Gate in your CI pipeline or as part of your test suite to avoid adding dependencies with problematic licenses.

To list all packages with their licenses, run `license_gate --report`:

```
✓ gem actioncable 8.1.4: MIT
✗ gem some-gem 1.2.0: GPL-3.0-only
✓ npm left-pad 1.3.0: MIT
…
```


## Example configuration

To get you started, here is an example `config/license_gate.yml`:

```yaml
# Licenses that any dependency may use.
# Case is ignored, and spaces match dashes, e.g. `bsd 2-Clause` works for `BSD-2-Clause`.
permitted_licenses:
  MIT: Permissive; only requires keeping the copyright notice
  ISC: Permissive; equivalent to MIT
  Apache-2.0: Permissive; requires keeping notices and includes a patent grant
  BSD-2-Clause: Permissive; only requires keeping the copyright notice
  BSD-3-Clause: Permissive; like BSD-2-Clause, but forbids promoting with the authors' names
  0BSD: Permissive without any conditions
  Ruby: License of Ruby and its default gems (like json); permissive, or BSD-2-Clause terms

# Licenses you do not permit globally, but accept for specific packages.
# Specify each exception explicitly.
# license_exceptions:
#   - gems: [prawn, pdf-core, ttfunk]
#     licenses: [Nonstandard]
#     why: Prawn offers its own variant of the permissive Ruby License (besides GPL)
#   - npm_packages: [some-old-library]
#     licenses: [Unknown] # declares no license at all
#     why: Its package.json lacks a license, but LICENSE file says MIT

# Dependency groups to skip. By default, everything is checked.
# ignored_groups:
#   bundler: [development, test]
#   npm: [devDependencies]
```


## Configuration

Licenses are named as your package managers report them, which is usually an [SPDX identifier](https://spdx.org/licenses/).
Unlisted licenses are considered not permitted.

### `permitted_licenses`

Maps licenses that any dependency may use to a reason why they are allowed.
A reason is recommended, but optional: use `true` or leave the value empty to permit a license without one.

### `license_exceptions`

Use this to specify a list of packages which may use licenses that are not generally permitted.
An entry has the following keys.
- `gems` and/or `npm_packages`: names of libraries
- `licenses`: licenses permitted for these packages
- `why`: reason these licenses are acceptable (optional, but recommended)

An exception specifies licenses, not only packages.
If a package changes to a license that isn't otherwise permitted, License Gate will report it.

### `ignored_groups`

Skips Bundler groups (`bundler`) and npm dependency types (`npm`).
For npm, `devDependencies` and `optionalDependencies` can be skipped (with Yarn, only `devDependencies`).

Both keys default to `[]`, i.e. nothing is skipped.


## How licenses are matched

- License names are compared ignoring case, with spaces and dashes being interchangeable; e.g. `BSD 2-Clause` matches `bsd-2-clause`.
- A gem may declare several licenses to choose from. When any of them is permitted, it passes.
- An npm package declares one license entry which may be an expression combining several licenses.
  - `(MIT OR Apache-2.0)` passes when one of them is permitted.
  - `(Apache-2.0 AND BSD-3-Clause)` requires all to be permitted.
  - Note that only uppercase `OR` and `AND` operators work.
- A package without any license counts as `Unknown`.
  If you encounter such a package, and its license is actually acceptable, we recommend specifying a `license_exceptions` entry for only that package.

### Known limitations

- Expressions mixing `OR` and `AND`, e.g. `(MIT AND Zlib) OR Apache-2.0`, or with nested parentheses, are not interpreted and will fail.
  You may permit any such string in full.
- `WITH` clauses are not interpreted, e.g. `Apache-2.0 WITH LLVM-exception` counts as a license of its own.
- A gem's licenses are treated as alternatives.
  Some gems list licenses that apply to different parts instead, e.g. MIT code with Apache-licensed data; License Gate cannot tell these apart.


## Supported package managers

### Bundler

Reads the Gemfile Bundler uses (`Gemfile`, `gems.rb` or `BUNDLE_GEMFILE`) and its lockfile.
Gems must be installed.
If some groups are not installed (through `BUNDLE_WITHOUT`, or `optional: true` groups), install them for the check, or list them in `ignored_groups.bundler`.

### pnpm

When your project root has a `pnpm-lock.yaml`, licenses of all workspace projects are checked through `pnpm licenses list`.
Packages must be installed (`node_modules`).

Requires pnpm 9 or later; tested with pnpm 9, 10, 11 and 12.

> [!WARNING]
> Older pnpm 11 and 12 releases report every license as `Unknown` with `nodeLinker: hoisted`.
> This is fixed in pnpm 11.28 and 12.7.

### Yarn

When your project root has a `yarn.lock`, licenses of all workspaces are checked through `yarn licenses list`.
With Yarn 4, packages must be installed, and installed again after every change to `yarn.lock`:
the check leaves out packages that `yarn.lock` lists but that are not installed.

Yarn Classic (1) has this command built in.
Yarn 4 needs the plugin [yarn-plugin-licenses](https://github.com/mhassan1/yarn-plugin-licenses) for this command, which you add to your project:

```
yarn plugin import https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.1/bundles/@yarnpkg/plugin-licenses.js
```

Yarn cannot leave out `optionalDependencies`, so `ignored_groups.npm` may only list `devDependencies`.

Tested with Yarn Classic (1), and with Yarn 4 using `nodeLinker: node-modules` and Plug'n'Play.

### Currently unsupported

License Gate does not yet support plain npm or other package managers.
Contributions adding them are welcome.

When your `package.json` declares dependencies, but there is neither a `pnpm-lock.yaml` nor a `yarn.lock` of a supported Yarn, it fails with an error.
It also fails when there are lockfiles of several package managers, e.g. a `pnpm-lock.yaml` and a `yarn.lock`.

Projects without npm dependencies are checked for gems only.


## Exit codes

| Exit code | Meaning |
| --- | --- |
| `0` | All dependencies use permitted licenses. |
| `1` | Some dependencies use licenses that are not permitted. They are listed in the output. |
| `2` | The check could not run, e.g. because the configuration is invalid or pnpm or Yarn failed. |


## Development

Run specs and RuboCop through `bundle exec rake`.
Specs require 100% line and branch coverage.

### Integration specs

The specs in `spec/integration` run License Gate against a real pnpm and Yarn.
Each runs when a version it covers is on your `PATH`, and is skipped otherwise.
With [mise](https://mise.jdx.dev/), `mise.toml` provides pnpm 12 and Yarn 4; select another version like `MISE_PNPM_VERSION=10`.

To test one version like a CI job does, set its major version and run only the integration specs:

```
TEST_PNPM=12 bundle exec rspec spec/integration
TEST_YARN=4 bundle exec rspec spec/integration
TEST_YARN=1 MISE_YARN_VERSION=1 bundle exec rspec spec/integration
```

The spec for that version then fails instead of being skipped, e.g. when another version is on your `PATH`.
Such runs do not check coverage; run the whole suite for that.


## Contributing

If you would like to contribute:

- Fork the repository.
- Push your changes with specs.
- Send a pull request.

It is important to us that we keep the gem lightweight and on topic.
If you're unsure whether a change would make it into the gem, open an issue and let's discuss.


## License

License Gate is available as open source under the [MIT License](LICENSE).
