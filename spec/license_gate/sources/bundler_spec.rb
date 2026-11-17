RSpec.describe LicenseGate::Sources::Bundler do

  describe '#packages' do
    it 'returns gems with their versions and licenses' do
      fixture_project.add_gem('alpha', licenses: ['MIT'])
      fixture_project.add_gem('beta', licenses: ['GPL-2.0-only', 'Ruby'])

      packages = described_class.new(fixture_project.gemfile, fixture_project.lockfile, ignored_groups: []).packages

      expect(packages).to include(
        LicenseGate::Package.new(ecosystem: :gem, name: 'alpha', version: '1.0.0', licenses: ['MIT']),
        LicenseGate::Package.new(ecosystem: :gem, name: 'beta', version: '1.0.0', licenses: ['GPL-2.0-only', 'Ruby']),
      )
    end

    it 'returns no licenses for a gem that sets its license to nil' do
      fixture_project.add_gem('alpha', licenses: [nil])

      packages = described_class.new(fixture_project.gemfile, fixture_project.lockfile, ignored_groups: []).packages

      expect(packages).to include(LicenseGate::Package.new(ecosystem: :gem, name: 'alpha', version: '1.0.0', licenses: []))
    end

    it 'leaves out gems of ignored groups' do
      fixture_project.add_gem('alpha', licenses: ['MIT'])
      fixture_project.add_gem('beta', licenses: ['MIT'], group: :development)
      fixture_project.add_gem('gamma', licenses: ['MIT'], group: :test)

      packages = described_class.new(fixture_project.gemfile, fixture_project.lockfile, ignored_groups: ['development']).packages

      expect(packages.map(&:name)).to include('alpha', 'gamma')
      expect(packages.map(&:name)).not_to include('beta')
    end

    it 'returns no gems when all groups are ignored' do
      fixture_project.add_gem('alpha', licenses: ['MIT'], group: :development)

      packages = described_class.new(fixture_project.gemfile, fixture_project.lockfile, ignored_groups: ['development']).packages

      expect(packages).to be_empty
    end
  end

end
