RSpec.describe LicenseGate::Configuration do

  def load_configuration(yaml)
    fixture_project.add_configuration(yaml)
    described_class.load(fixture_project.root.join('config/license_gate.yml'), 'config/license_gate.yml')
  end

  def package(ecosystem, name)
    LicenseGate::Package.new(ecosystem:, name:, version: '1.0.0', licenses: [])
  end

  describe '#permitted_licenses_for' do
    it 'returns permitted licenses, whether given with a reason, true or empty' do
      configuration = load_configuration(<<~YAML)
        permitted_licenses:
          MIT: Permissive
          BSD 2-Clause: true
          ISC:
      YAML

      expect(configuration.permitted_licenses_for(package(:gem, 'rails'))).to contain_exactly('MIT', 'BSD 2-Clause', 'ISC')
    end

    it 'adds licenses of exceptions naming the package within its ecosystem' do
      configuration = load_configuration(<<~YAML)
        permitted_licenses:
          MIT:
        license_exceptions:
          - gems: [prawn, ttfunk]
            licenses: [GPL-2.0-only, GPL-3.0-only]
            why: We only distribute its output
          - npm_packages: [caniuse-lite]
            licenses: [CC-BY-4.0]
      YAML

      expect(configuration.permitted_licenses_for(package(:gem, 'prawn'))).to contain_exactly('MIT', 'GPL-2.0-only', 'GPL-3.0-only')
      expect(configuration.permitted_licenses_for(package(:npm, 'prawn'))).to contain_exactly('MIT')
      expect(configuration.permitted_licenses_for(package(:npm, 'caniuse-lite'))).to contain_exactly('MIT', 'CC-BY-4.0')
    end

    it 'accepts an empty list of packages next to another one' do
      configuration = load_configuration(<<~YAML)
        license_exceptions:
          - gems:
            npm_packages: [chart.js]
            licenses: [MIT]
      YAML

      expect(configuration.permitted_licenses_for(package(:gem, 'rails'))).to be_empty
      expect(configuration.permitted_licenses_for(package(:npm, 'chart.js'))).to contain_exactly('MIT')
    end

    it 'resolves YAML aliases, e.g. for shared reasons' do
      configuration = load_configuration(<<~YAML)
        permitted_licenses:
          MIT: &permissive Permissive license
          ISC: *permissive
      YAML

      expect(configuration.permitted_licenses_for(package(:gem, 'rails'))).to contain_exactly('MIT', 'ISC')
    end
  end

  describe '#ignored_bundler_groups and #ignored_npm_groups' do
    it 'ignores no groups by default' do
      configuration = load_configuration(<<~YAML)
        permitted_licenses:
          MIT:
      YAML

      expect(configuration).to have_attributes(ignored_bundler_groups: [], ignored_npm_groups: [])
    end

    it 'replaces each default on its own' do
      configuration = load_configuration(<<~YAML)
        ignored_groups:
          bundler: [development, test]
      YAML

      expect(configuration).to have_attributes(ignored_bundler_groups: %w[development test], ignored_npm_groups: [])
    end

    it 'reads ignored npm groups' do
      configuration = load_configuration(<<~YAML)
        ignored_groups:
          npm: [devDependencies, optionalDependencies]
      YAML

      expect(configuration).to have_attributes(ignored_bundler_groups: [], ignored_npm_groups: %w[devDependencies optionalDependencies])
    end
  end

  describe '.load' do
    it 'fails when the file does not exist' do
      expect { described_class.load(fixture_project.root.join('missing.yml'), 'missing.yml') }
        .to raise_error(LicenseGate::ConfigurationError, 'missing.yml not found')
    end

    it 'fails for invalid YAML' do
      expect { load_configuration('permitted_licenses: [MIT') }
        .to raise_error(LicenseGate::ConfigurationError, /\Aconfig\/license_gate.yml is not valid YAML: .+ \(line \d+, column \d+\)\z/)
    end

    it 'fails for YAML that cannot be loaded, e.g. with an undefined alias' do
      expect { load_configuration("permitted_licenses:\n  MIT: *permisive\n") }
        .to raise_error(LicenseGate::ConfigurationError, /\Aconfig\/license_gate.yml is not valid YAML: .*permisive/)
    end

    it 'fails for an empty file' do
      expect { load_configuration('') }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml is empty')
    end

    it 'fails for an unknown key' do
      expect { load_configuration("permited_licenses:\n  MIT:\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: unknown key "permited_licenses" in the configuration (expected one of permitted_licenses, license_exceptions, ignored_groups)',
      )
    end

    it 'fails for an unknown key YAML reads as false' do
      expect { load_configuration("ignored_groups:\n  no: [development]\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: unknown key false in ignored_groups (expected one of bundler, npm)',
      )
    end

    it 'fails for a permitted license YAML does not read as a String' do
      expect { load_configuration("permitted_licenses:\n  1.0: true\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: key 1.0 in permitted_licenses must be a String, but is Float',
      )
    end

    it 'fails when permitted licenses are not a hash' do
      expect { load_configuration('permitted_licenses: [MIT]') }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: permitted_licenses must be a Hash, but is ["MIT"]')
    end

    it 'fails for a reason that is neither a String, true nor empty' do
      expect { load_configuration("permitted_licenses:\n  MIT: false\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: reason at permitted_licenses.MIT must be a String, true or empty, but is false',
      )
    end

    it 'fails when license exceptions are not a list' do
      inspection = { 'gems' => ['prawn'] }.inspect # Hash inspection changed with Ruby 3.4

      expect { load_configuration("license_exceptions:\n  gems: [prawn]\n") }
        .to raise_error(LicenseGate::ConfigurationError, "config/license_gate.yml: license_exceptions must be an Array, but is #{inspection}")
    end

    it 'fails for a license exception that is not a hash' do
      expect { load_configuration("license_exceptions:\n  - prawn\n") }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: license_exceptions[0] must be a Hash, but is "prawn"')
    end

    it 'fails for an unknown key in a license exception' do
      expect { load_configuration("license_exceptions:\n  - gem: [prawn]\n    licenses: [GPL-3.0-only]\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: unknown key "gem" in license_exceptions[0] (expected one of gems, npm_packages, licenses, why)',
      )
    end

    it 'fails for a license exception without licenses' do
      expect { load_configuration("license_exceptions:\n  - gems: [prawn]\n") }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: license_exceptions[0].licenses must be a non-empty Array of Strings, but is nil')
    end

    it 'fails for a license exception without packages' do
      expect { load_configuration("license_exceptions:\n  - licenses: [GPL-3.0-only]\n") }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: license_exceptions[0] must list at least one package in gems or npm_packages (Arrays of Strings)')
    end

    it 'fails for a license exception whose lists of packages are all empty' do
      expect { load_configuration("license_exceptions:\n  - gems: []\n    npm_packages:\n    licenses: [GPL-3.0-only]\n") }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: license_exceptions[0] must list at least one package in gems or npm_packages (Arrays of Strings)')
    end

    it 'fails for a license exception whose reason is neither a String, true nor empty' do
      expect { load_configuration("license_exceptions:\n  - gems: [prawn]\n    licenses: [GPL-3.0-only]\n    why: [server-side]\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: reason at license_exceptions[0].why must be a String, true or empty, but is ["server-side"]',
      )
    end

    it 'fails when ignored groups are not a hash' do
      expect { load_configuration('ignored_groups: [development]') }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: ignored_groups must be a Hash, but is ["development"]')
    end

    it 'fails for an unknown key in ignored groups' do
      expect { load_configuration("ignored_groups:\n  yarn: []\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: unknown key "yarn" in ignored_groups (expected one of bundler, npm)',
      )
    end

    it 'fails when ignored Bundler groups are not a list' do
      expect { load_configuration("ignored_groups:\n  bundler: development\n") }
        .to raise_error(LicenseGate::ConfigurationError, 'config/license_gate.yml: ignored_groups.bundler must be an Array of Strings, but is "development"')
    end

    it 'fails for an ignored npm group pnpm cannot leave out' do
      expect { load_configuration("ignored_groups:\n  npm: [dependencies]\n") }.to raise_error(
        LicenseGate::ConfigurationError,
        'config/license_gate.yml: ignored_groups.npm may only list devDependencies and optionalDependencies, but is ["dependencies"]',
      )
    end
  end

end
