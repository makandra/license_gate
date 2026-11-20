RSpec.describe 'license_gate with a real Yarn 2 or later' do

  include_context 'with a real Yarn', 2.., 'Yarn 2 or later'

  context 'with the plugin' do
    before do
      plugin_url = (major_version == 2) ? LicenseGate::Sources::Yarn::YARN_2_PLUGIN_URL : LicenseGate::Sources::Yarn::PLUGIN_URL
      output, status = run('yarn', 'plugin', 'import', plugin_url)
      raise "yarn plugin import failed:\n#{output}" unless status.success?
    end

    it_behaves_like 'a check with a real Yarn'
  end

  it 'fails with a hint when Yarn lacks the plugin' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(2)
    expect(output).to include('Yarn lacks the plugin yarn-plugin-licenses')
  end

end
