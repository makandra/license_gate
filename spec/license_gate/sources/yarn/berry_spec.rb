RSpec.describe LicenseGate::Sources::Yarn::Berry do

  describe '#packages' do
    it 'returns one package per locator, with its version from the lockfile' do
      fixture_project.add_yarn_berry_packages(
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

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages).to contain_exactly(
        LicenseGate::Package.new(ecosystem: :npm, name: 'left-pad', version: '1.3.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: '@types/node', version: '24.0.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '2.8.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '1.14.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'local-package', version: '0.1.0', licenses: ['ISC']),
      )
    end

    it 'returns packages with peer dependencies, which Yarn reports as virtual packages' do
      fixture_project.add_yarn_berry_packages(
        { 'MIT' => ['debug@virtual:4d81cd1261874f39#npm:4.4.0'] },
        'debug@npm:4.4.0' => '4.4.0',
      )

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages).to eq([LicenseGate::Package.new(ecosystem: :npm, name: 'debug', version: '4.4.0', licenses: ['MIT'])])
    end

    it 'returns a package once, even when Yarn reports it under several locators' do
      root_locator = 'shared@file:./vendor/shared#./vendor/shared::hash=3a3b0c&locator=root%40workspace%3A.'
      sub_locator = 'shared@file:../../vendor/shared#../../vendor/shared::hash=3a3b0c&locator=sub%40workspace%3Aprojects%2Fsub'
      fixture_project.add_yarn_berry_packages({ 'MIT' => [root_locator, sub_locator] }, root_locator => '1.0.0', sub_locator => '1.0.0')

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages).to eq([LicenseGate::Package.new(ecosystem: :npm, name: 'shared', version: '1.0.0', licenses: ['MIT'])])
    end

    it 'leaves out workspaces' do
      fixture_project.add_yarn_berry_packages(
        { 'UNKNOWN' => ['root@workspace:.', 'sub@workspace:projects/sub', 'unlicensed-package@npm:1.0.0'] },
        'root@workspace:.' => '0.0.0-use.local',
        'sub@workspace:projects/sub' => '0.0.0-use.local',
        'unlicensed-package@npm:1.0.0' => '1.0.0',
      )

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages.map(&:name)).to eq(['unlicensed-package'])
    end
  end

end
