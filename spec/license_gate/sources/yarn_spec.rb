RSpec.describe LicenseGate::Sources::Yarn do

  describe '#packages' do
    it 'returns one package per locator, with its version from the lockfile' do
      fixture_project.add_yarn_packages(
        {
          'MIT' => ['left-pad@npm:1.3.0', '@types/node@npm:24.0.0'],
          '(MIT OR Apache-2.0)' => ['tslib@npm:2.8.1', 'tslib@npm:1.14.1'],
          'ISC' => ['local-package@file:./vendor/local-package#./vendor/local-package::hash=3a3b0c&locator=root%40workspace%3A.'],
        },
        'left-pad@npm:1.3.0' => '1.3.0',
        '@types/node@npm:24.0.0' => '24.0.0',
        'tslib@npm:2.8.1' => '2.8.1',
        'tslib@npm:1.14.1' => '1.14.1',
        'local-package@file:./vendor/local-package#./vendor/local-package::hash=3a3b0c&locator=root%40workspace%3A.' => '0.1.0',
      )

      packages = described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(packages).to contain_exactly(
        LicenseGate::Package.new(ecosystem: :npm, name: 'left-pad', version: '1.3.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: '@types/node', version: '24.0.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '2.8.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '1.14.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'local-package', version: '0.1.0', licenses: ['ISC']),
      )
    end

    it 'returns packages with peer dependencies, which Yarn reports as virtual packages' do
      fixture_project.add_yarn_packages(
        { 'MIT' => ['debug@virtual:4d81cd1261874f39#npm:4.4.0'] },
        'debug@npm:4.4.0' => '4.4.0',
      )

      packages = described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(packages).to eq([LicenseGate::Package.new(ecosystem: :npm, name: 'debug', version: '4.4.0', licenses: ['MIT'])])
    end

    it 'returns a package once, even when Yarn reports it under several locators' do
      root_locator = 'shared@file:./vendor/shared#./vendor/shared::hash=3a3b0c&locator=root%40workspace%3A.'
      sub_locator = 'shared@file:../../vendor/shared#../../vendor/shared::hash=3a3b0c&locator=sub%40workspace%3Aprojects%2Fsub'
      fixture_project.add_yarn_packages({ 'MIT' => [root_locator, sub_locator] }, root_locator => '1.0.0', sub_locator => '1.0.0')

      packages = described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(packages).to eq([LicenseGate::Package.new(ecosystem: :npm, name: 'shared', version: '1.0.0', licenses: ['MIT'])])
    end

    it 'leaves out workspaces' do
      fixture_project.add_yarn_packages(
        { 'UNKNOWN' => ['root@workspace:.', 'sub@workspace:projects/sub', 'unlicensed-package@npm:1.0.0'] },
        'root@workspace:.' => '0.0.0-use.local',
        'sub@workspace:projects/sub' => '0.0.0-use.local',
        'unlicensed-package@npm:1.0.0' => '1.0.0',
      )

      packages = described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(packages.map(&:name)).to eq(['unlicensed-package'])
    end

    it 'lists all groups by default' do
      fixture_project.add_yarn_packages({})

      described_class.new(fixture_project.root, ignored_groups: []).packages

      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive])
    end

    it 'leaves out devDependencies when they are ignored' do
      fixture_project.add_yarn_packages({})

      described_class.new(fixture_project.root, ignored_groups: ['devDependencies']).packages

      expect(fixture_project.package_manager_arguments).to eq(%w[licenses list --json --recursive --production])
    end

    it 'fails for ignored optionalDependencies, which Yarn cannot leave out' do
      fixture_project.add_yarn_packages({})

      expect { described_class.new(fixture_project.root, ignored_groups: ['optionalDependencies']).packages }
        .to raise_error(LicenseGate::ConfigurationError, 'ignored_groups.npm: Yarn cannot leave out optionalDependencies')
    end

    it "fails with Yarn's output" do
      fixture_project.add_yarn_packages({})
      fixture_project.fail_package_manager(
        stdout: "Internal Error: ENOENT: no such file or directory, open 'node_modules/.yarn-state.yml'\n",
        stderr: "(node:42) Warning: some deprecation\n",
      )

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }.to raise_error(
        LicenseGate::YarnError,
        "`yarn licenses list --json --recursive` failed:\n" \
        "Internal Error: ENOENT: no such file or directory, open 'node_modules/.yarn-state.yml'\n" \
        "(node:42) Warning: some deprecation\n",
      )
    end

    it 'fails with a hint when Yarn lacks the plugin' do
      fixture_project.add_yarn_packages({})
      fixture_project.fail_package_manager(stdout: "Usage Error: Couldn't find a script named \"licenses\".\n")

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }.to raise_error(
        LicenseGate::YarnError,
        'yarn.lock found, but Yarn lacks the plugin yarn-plugin-licenses; ' \
        'add it with `yarn plugin import https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.0/bundles/@yarnpkg/plugin-licenses.js` ' \
        '(with Yarn 2: `yarn plugin import https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.6.0/bundles/@yarnpkg/plugin-licenses.js`)',
      )
    end

    it 'reads non-ASCII package metadata under a non-UTF-8 locale' do
      fixture_project.add_yarn_packages({}, 'cross-spawn@npm:7.0.6' => '7.0.6')
      children = { 'cross-spawn@npm:7.0.6' => { 'children' => { 'vendorName' => 'André Cruz' } } }
      fixture_project.write('fake-output', JSON.generate('value' => 'MIT', 'children' => children))
      external_encoding_was = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII

      expect(described_class.new(fixture_project.root, ignored_groups: []).packages.map(&:name)).to eq(['cross-spawn'])
    ensure
      Encoding.default_external = external_encoding_was
    end

    it 'fails when Yarn is not installed' do
      fixture_project.add_yarn_packages({})
      path_was = ENV.fetch('PATH')
      ENV['PATH'] = fixture_project.root.to_s

      expect { described_class.new(fixture_project.root, ignored_groups: []).packages }
        .to raise_error(LicenseGate::YarnError, 'yarn.lock found, but Yarn is not installed')
    ensure
      ENV['PATH'] = path_was
    end
  end

end
