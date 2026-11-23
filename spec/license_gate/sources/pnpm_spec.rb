RSpec.describe LicenseGate::Sources::Pnpm do

  describe '.responsible_for?' do
    it 'is true with a pnpm-lock.yaml' do
      fixture_project.write('pnpm-lock.yaml', '')

      expect(described_class.responsible_for?(fixture_project.root)).to be(true)
    end

    it 'is false without a pnpm-lock.yaml' do
      expect(described_class.responsible_for?(fixture_project.root)).to be(false)
    end
  end

  describe '#packages' do
    it 'returns one package per name and version' do
      fixture_project.add_pnpm_packages(
        'MIT' => { 'left-pad' => ['1.3.0'] },
        '(MIT OR Apache-2.0)' => { 'tslib' => ['2.8.1', '1.14.1'] },
      )

      packages = described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(packages).to contain_exactly(
        LicenseGate::Package.new(ecosystem: :npm, name: 'left-pad', version: '1.3.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '2.8.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '1.14.1', licenses: ['(MIT OR Apache-2.0)']),
      )
    end

    it 'returns no packages when an older pnpm reports that it found none' do
      fixture_project.add_pnpm_packages({})
      fixture_project.write('fake-output', "No licenses in packages found\n")

      expect(described_class.new(fixture_project.root, ignored_groups: []).packages).to eq([])
    end

    it 'fails with a hint on the pnpm version when entries lack versions' do
      fixture_project.add_pnpm_packages({})
      entry = { 'name' => 'left-pad', 'version' => '1.3.0', 'license' => 'MIT' }
      fixture_project.write('fake-output', JSON.generate('MIT' => [entry]))

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::PnpmError, 'unexpected output from `pnpm licenses list`; pnpm 9 or later is required')
    end

    it 'lists all groups by default' do
      fixture_project.add_pnpm_packages({})

      described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive])
    end

    it 'leaves out ignored groups' do
      fixture_project.add_pnpm_packages({})

      described_class.new(fixture_project.root, ignored_groups: %w[devDependencies optionalDependencies]).packages

      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive --prod --no-optional])
    end

    it "fails with pnpm's error output" do
      fixture_project.add_pnpm_packages({})
      fixture_project.fail_package_manager(stderr: "ERR_PNPM_NO_LOCKFILE\n")

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::PnpmError, "`pnpm licenses list --json --recursive` failed:\nERR_PNPM_NO_LOCKFILE\n")
    end

    it 'fails with the output of a pnpm that reports errors on stdout' do
      fixture_project.add_pnpm_packages({})
      fixture_project.fail_package_manager(stdout: '{"error": {"code": "ERR_PNPM_MISSING_PACKAGE_INDEX_FILE"}}')

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }.to raise_error(
        LicenseGate::PnpmError,
        "`pnpm licenses list --json --recursive` failed:\n{\"error\": {\"code\": \"ERR_PNPM_MISSING_PACKAGE_INDEX_FILE\"}}",
      )
    end

    it 'fails with both outputs of a pnpm that writes to stdout and stderr' do
      fixture_project.add_pnpm_packages({})
      fixture_project.fail_package_manager(stdout: "Progress\n", stderr: "ERR_PNPM_NO_LOCKFILE\n")

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::PnpmError, "`pnpm licenses list --json --recursive` failed:\nProgress\nERR_PNPM_NO_LOCKFILE\n")
    end

    it 'reads non-ASCII package metadata under a non-UTF-8 locale' do
      fixture_project.add_pnpm_packages({})
      entry = { 'name' => 'cross-spawn', 'versions' => ['7.0.6'], 'license' => 'MIT', 'author' => 'André Cruz' }
      fixture_project.write('fake-output', JSON.generate('MIT' => [entry]))
      external_encoding_was = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII

      expect(described_class.new(fixture_project.root, ignored_groups: []).packages.map(&:name)).to eq(['cross-spawn'])
    ensure
      Encoding.default_external = external_encoding_was
    end

    it 'fails when npm packages are not installed, even with an empty node_modules' do
      fixture_project.add_pnpm_packages('MIT' => { 'left-pad' => ['1.3.0'] })
      fixture_project.root.join('node_modules/.modules.yaml').delete

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::PnpmError, 'pnpm-lock.yaml found, but packages are not installed; run `pnpm install` first')
    end

    it 'fails when pnpm is not installed' do
      fixture_project.add_pnpm_packages({})
      path_was = ENV.fetch('PATH')
      ENV['PATH'] = fixture_project.root.to_s

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::PnpmError, 'pnpm-lock.yaml found, but pnpm is not installed')
    ensure
      ENV['PATH'] = path_was
    end
  end

end
