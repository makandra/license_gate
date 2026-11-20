RSpec.describe LicenseGate::Sources::Yarn::Legacy do

  describe '#packages' do
    it 'returns one package per name and version' do
      fixture_project.add_yarn_legacy_packages(
        'MIT' => { 'left-pad' => ['1.3.0'], '@types/node' => ['24.0.0'] },
        '(MIT OR Apache-2.0)' => { 'tslib' => ['2.8.1', '1.14.1'] },
      )

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages).to contain_exactly(
        LicenseGate::Package.new(ecosystem: :npm, name: 'left-pad', version: '1.3.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: '@types/node', version: '24.0.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '2.8.1', licenses: ['(MIT OR Apache-2.0)']),
        LicenseGate::Package.new(ecosystem: :npm, name: 'tslib', version: '1.14.1', licenses: ['(MIT OR Apache-2.0)']),
      )
    end

    it 'leaves out workspaces and the package Yarn gathers them in' do
      fixture_project.add_yarn_legacy_packages(
        'UNKNOWN' => { 'sub' => ['1.0.0'], 'workspace-aggregator-0b6124' => [''], 'unlicensed-package' => ['1.0.0'] },
      )
      fixture_project.write('package.json', '{"workspaces": ["projects/*"]}')
      fixture_project.write('projects/sub/package.json', '{"name": "sub", "version": "1.0.0"}')

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages.map(&:name)).to eq(['unlicensed-package'])
    end

    it 'finds workspaces configured with packages and nohoist' do
      fixture_project.add_yarn_legacy_packages('UNKNOWN' => { 'sub' => ['1.0.0'] })
      fixture_project.write('package.json', '{"workspaces": {"packages": ["projects/*"], "nohoist": ["**/react"]}}')
      fixture_project.write('projects/sub/package.json', '{"name": "sub", "version": "1.0.0"}')

      expect(described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)).to eq([])
    end

    it 'keeps packages installed below a workspace, even when its glob matches them' do
      fixture_project.add_yarn_legacy_packages('GPL-3.0-only' => { 'copyleft' => ['2.0.0'] })
      fixture_project.write('package.json', '{"workspaces": ["projects/**"]}')
      fixture_project.write('projects/sub/package.json', '{"name": "sub", "version": "1.0.0"}')
      fixture_project.write('projects/sub/node_modules/copyleft/package.json', '{"name": "copyleft", "version": "2.0.0"}')

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages.map(&:name)).to eq(['copyleft'])
    end

    it 'keeps packages that only share their name with a workspace' do
      fixture_project.add_yarn_legacy_packages('MIT' => { 'sub' => ['1.0.0', '3.0.0'] })
      fixture_project.write('package.json', '{"workspaces": ["projects/*"]}')
      fixture_project.write('projects/sub/package.json', '{"name": "sub", "version": "1.0.0"}')

      packages = described_class.new(fixture_project.root).packages(fixture_project.package_manager_output)

      expect(packages.map(&:version)).to eq(['3.0.0'])
    end

    it 'reads non-ASCII manifests under a non-UTF-8 locale' do
      fixture_project.add_yarn_legacy_packages('MIT' => { 'cross-spawn' => ['7.0.6'] })
      fixture_project.write('package.json', '{"description": "Prüfung", "workspaces": ["projects/*"]}')
      fixture_project.write('projects/sub/package.json', '{"name": "sub", "author": "André Cruz"}')
      output = fixture_project.package_manager_output
      external_encoding_was = Encoding.default_external
      Encoding.default_external = Encoding::US_ASCII

      expect(described_class.new(fixture_project.root).packages(output).map(&:name)).to eq(['cross-spawn'])
    ensure
      Encoding.default_external = external_encoding_was
    end
  end

end
