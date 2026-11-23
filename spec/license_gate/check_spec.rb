RSpec.describe LicenseGate::Check do

  def check
    configuration = LicenseGate::Configuration.load(fixture_project.root.join('config/license_gate.yml'), 'config/license_gate.yml')
    described_class.new(configuration, gemfile: fixture_project.gemfile, lockfile: fixture_project.lockfile).run
  end

  describe '#run' do
    it 'returns all packages and those whose licenses are not permitted, both ordered by ecosystem and name' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
      YAML
      fixture_project.add_gem('zeta', licenses: ['GPL-3.0-only'])
      fixture_project.add_gem('alpha', licenses: ['AGPL-3.0-only'])
      fixture_project.add_gem('beta', licenses: ['MIT'])
      fixture_project.add_pnpm_packages('ISC' => { 'glob' => ['10.0.0'] }, 'MIT' => { 'left-pad' => ['1.3.0'] })

      result = check

      expect(result.violations.map(&:to_s)).to eq(['gem alpha 1.0.0', 'gem zeta 1.0.0', 'npm glob 10.0.0'])
      expect(result.packages.map(&:name)).to eq(%w[alpha beta bundler zeta glob left-pad])
    end

    it 'permits a gem when any of its licenses is permitted' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
          Ruby:
      YAML
      fixture_project.add_gem('rdoc', licenses: ['GPL-2.0-only', 'Ruby'])

      expect(check.violations).to be_empty
    end

    it 'permits further licenses only for packages of an exception' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
        license_exceptions:
          - gems: [prawn]
            licenses: [GPL-3.0-only]
      YAML
      fixture_project.add_gem('prawn', licenses: ['GPL-3.0-only'])
      fixture_project.add_gem('other', licenses: ['GPL-3.0-only'])

      expect(check.violations.map(&:name)).to eq(['other'])
    end

    it 'treats a gem without licenses as Unknown' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
        license_exceptions:
          - gems: [old-gem]
            licenses: [Unknown]
      YAML
      fixture_project.add_gem('old-gem', licenses: [])
      fixture_project.add_gem('other-old-gem', licenses: [])

      expect(check.violations.map(&:name)).to eq(['other-old-gem'])
    end

    it 'checks npm packages only with a lockfile of a supported package manager' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
      YAML
      fixture_project.add_gem('alpha', licenses: ['MIT'])

      result = check

      expect(result.npm_checked).to be(false)
      expect(result.packages.map(&:ecosystem)).to all(eq(:gem))
    end

    it 'leaves out ignored groups' do
      fixture_project.add_configuration(<<~YAML)
        ignored_groups:
          bundler: [development]
          npm: [devDependencies]
      YAML
      fixture_project.add_gem('debug-helper', licenses: ['GPL-3.0-only'], group: :development)
      fixture_project.add_pnpm_packages({})

      expect(check.packages.map(&:name)).not_to include('debug-helper')
      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive --prod])
    end

    it 'checks npm packages through Yarn 4 with its yarn.lock' do
      fixture_project.add_configuration(<<~YAML)
        permitted_licenses:
          MIT:
        ignored_groups:
          npm: [devDependencies]
      YAML
      fixture_project.add_yarn_berry_packages({ 'GPL-3.0-only' => ['copyleft@npm:2.0.0'] }, 'copyleft@npm:2.0.0' => '2.0.0')

      result = check

      expect(result.violations.map(&:to_s)).to eq(['npm copyleft 2.0.0'])
      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive --production])
    end

    it 'checks npm packages through Yarn Classic with its yarn.lock' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_yarn_classic_packages('GPL-3.0-only' => { 'copyleft' => ['2.0.0'] })

      expect(check.violations.map(&:to_s)).to eq(['npm copyleft 2.0.0'])
    end

    it 'fails for lockfiles of several package managers' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_pnpm_packages({})
      fixture_project.add_yarn_berry_packages({})

      expect { check }.to raise_error(
        LicenseGate::UnsupportedPackageManagerError,
        'found pnpm-lock.yaml and yarn.lock; delete the lockfile of the package manager you no longer use',
      )
    end

    it 'skips npm packages for a package.json without dependencies' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.write('package.json', '{"scripts": {"build": "esbuild"}, "dependencies": {}}')

      expect(check.npm_checked).to be(false)
    end

    it 'fails when package.json declares dependencies without a lockfile of a supported package manager' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.write('package.json', '{"devDependencies": {"eslint": "^10.0.0"}}')
      fixture_project.write('yarn.lock', '')

      expect { check }.to raise_error(
        LicenseGate::UnsupportedPackageManagerError,
        'package.json declares dependencies, but there is no pnpm-lock.yaml or yarn.lock of a supported package manager',
      )
    end
  end

end
