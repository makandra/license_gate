RSpec.describe 'license_gate with a real Yarn' do

  include_context 'with a real package manager', 'yarn', 2.., 'Yarn 2 or later'

  def install
    output, status = run('yarn', 'install')
    raise "yarn install failed:\n#{output}" unless status.success?
  end

  context 'with the plugin' do
    before do
      plugin_url = (major_version == 2) ? LicenseGate::Sources::Yarn::YARN_2_PLUGIN_URL : LicenseGate::Sources::Yarn::PLUGIN_URL
      output, status = run('yarn', 'plugin', 'import', plugin_url)
      raise "yarn plugin import failed:\n#{output}" unless status.success?
    end

    it 'reports npm packages of all workspaces whose licenses are not permitted' do
      project.join('config').mkpath
      project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

      output, status = run(*command)

      expect(status.exitstatus).to eq(1)
      expect(output)
        .to match(/^✗ npm dev-package 1\.0\.0: GPL-3\.0-only$/)
        .and match(/^✗ npm optional-package 1\.0\.0: BSD-3-Clause$/)
        .and match(/^✗ npm sub-package 1\.0\.0: ISC$/)
        .and match(/^✗ npm unlicensed-package 1\.0\.0: UNKNOWN \(no license found\)$/)
        .and include('4 of 5 packages use licenses that are not permitted.')
    end

    it 'leaves out devDependencies when they are ignored' do
      project.join('config').mkpath
      project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n  ISC:\nignored_groups:\n  npm: [devDependencies]\n")

      output, status = run(*command)

      expect(status.exitstatus).to eq(1)
      expect(output)
        .to include('2 of 4 packages use licenses that are not permitted.')
        .and not_include('dev-package')
    end
  end

  it 'fails with a hint when Yarn lacks the plugin' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(2)
    expect(output).to include('Yarn lacks the plugin yarn-plugin-licenses')
  end

end
