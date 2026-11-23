RSpec.describe LicenseGate::CLI do

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  def run_cli(*arguments)
    described_class.new(arguments, out:, err:, gemfile: fixture_project.gemfile, lockfile: fixture_project.lockfile).run
  end

  describe '#run' do
    it 'reports success and returns 0 when all licenses are permitted' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])
      fixture_project.add_pnpm_packages('MIT' => { 'left-pad' => ['1.3.0'], 'tslib' => ['2.8.1', '1.14.1'] })

      expect(run_cli).to eq(0)
      expect(out.string).to eq("All 5 packages use permitted licenses (2 gems, 3 npm packages).\n")
    end

    it 'lists packages whose licenses are not permitted and returns 1' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])
      fixture_project.add_gem('beta', licenses: ['GPL-2.0-only', 'GPL-3.0-only'])
      fixture_project.add_gem('gamma', licenses: [])
      fixture_project.add_pnpm_packages(
        '(MIT AND Zlib) OR Apache-2.0' => { 'foo' => ['1.2.3'] },
        'Unknown' => { 'bar' => ['0.4.0'] },
      )

      expect(run_cli).to eq(1)
      expect(out.string).to eq(<<~TEXT)
        ✗ gem beta 1.0.0: GPL-2.0-only OR GPL-3.0-only
        ✗ gem gamma 1.0.0: Unknown (no license found)
        ✗ npm bar 0.4.0: Unknown (no license found)
        ✗ npm foo 1.2.3: (MIT AND Zlib) OR Apache-2.0 (unsupported expression)

        4 of 6 packages use licenses that are not permitted.
        Permit a license in config/license_gate.yml, or add a license exception with a reason.
      TEXT
    end

    it 'lists all packages with --report' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])
      fixture_project.add_gem('beta', licenses: ['GPL-3.0-only'])
      fixture_project.add_pnpm_packages('MIT' => { 'left-pad' => ['1.3.0'] }, 'Unknown' => { 'bar' => ['0.4.0'] })

      expect(run_cli('--report')).to eq(1)
      expect(out.string).to eq(<<~TEXT)
        ✓ gem alpha 1.0.0: MIT
        ✗ gem beta 1.0.0: GPL-3.0-only
        ✓ gem bundler #{Bundler::VERSION}: MIT
        ✗ npm bar 0.4.0: Unknown (no license found)
        ✓ npm left-pad 1.3.0: MIT

        2 of 5 packages use licenses that are not permitted.
        Permit a license in config/license_gate.yml, or add a license exception with a reason.
      TEXT
    end

    it 'lists all packages with --report when all licenses are permitted' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])

      expect(run_cli('--report')).to eq(0)
      expect(out.string).to eq(<<~TEXT)
        npm packages: not checked (no pnpm-lock.yaml or yarn.lock)
        ✓ gem alpha 1.0.0: MIT
        ✓ gem bundler #{Bundler::VERSION}: MIT

        All 2 packages use permitted licenses (2 gems, 0 npm packages).
      TEXT
    end

    it 'mentions when npm packages are not checked' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])

      expect(run_cli).to eq(0)
      expect(out.string).to eq(<<~TEXT)
        npm packages: not checked (no pnpm-lock.yaml or yarn.lock)
        All 2 packages use permitted licenses (2 gems, 0 npm packages).
      TEXT
    end

    it 'reads its configuration from a file passed as --config' do
      configuration_path = fixture_project.root.join('licenses.yml').to_s
      fixture_project.write('licenses.yml', "permitted_licenses:\n  ISC:\n")
      fixture_project.add_gem('alpha', licenses: ['MIT'])

      expect(run_cli('--config', configuration_path)).to eq(1)
      expect(out.string).to end_with("Permit a license in #{configuration_path}, or add a license exception with a reason.\n")
    end

    it 'checks the project of the current bundle by default' do
      configuration_path = fixture_project.root.join('nothing_permitted.yml').to_s
      fixture_project.write('nothing_permitted.yml', "permitted_licenses: {}\n")

      exit_code = described_class.new(['--config', configuration_path], out:, err:).run

      expect(exit_code).to eq(1)
      expect(out.string).to include('✗ gem rspec ')
    end

    it 'reports an invalid configuration and returns 2' do
      fixture_project.add_configuration("permited_licenses:\n  MIT:\n")

      expect(run_cli).to eq(2)
      expect(err.string).to start_with('license_gate: config/license_gate.yml: unknown key "permited_licenses"')
    end

    it 'reports a Gemfile Bundler cannot resolve and returns 2' do
      fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
      fixture_project.write('Gemfile', "gem 'missing', path: 'gems/missing'\n")

      expect(run_cli).to eq(2)
      expect(err.string).to start_with('license_gate: ').and include('gems/missing')
    end

    it 'reports any other error that prevents the check and returns 2' do
      expect(run_cli('--config', fixture_project.root.to_s)).to eq(2)
      expect(err.string).to start_with('license_gate: Is a directory')
    end

    it 'reports an unknown option and returns 2' do
      expect(run_cli('--verbose')).to eq(2)
      expect(err.string).to eq("license_gate: invalid option: --verbose\n")
    end

    it 'reports an unexpected argument and returns 2' do
      expect(run_cli('licenses.yml')).to eq(2)
      expect(err.string).to eq("license_gate: unexpected argument \"licenses.yml\"\n")
    end

    it 'prints the help' do
      expect(run_cli('--help')).to eq(0)
      expect(out.string).to start_with('Usage: license_gate [options]').and include('--config PATH')
    end

    it 'prints the version' do
      expect(run_cli('--version')).to eq(0)
      expect(out.string).to eq("#{LicenseGate::VERSION}\n")
    end
  end

end
