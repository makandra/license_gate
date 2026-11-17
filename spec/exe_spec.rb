RSpec.describe 'exe/license_gate' do

  let(:command) { [RbConfig.ruby, '-I', File.expand_path('../lib', __dir__), File.expand_path('../exe/license_gate', __dir__)] }

  it 'checks the project in the working directory and exits with the check result' do
    fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
    fixture_project.add_gem('alpha', licenses: ['GPL-3.0-only'])

    output, status = Bundler.with_unbundled_env do
      Open3.capture2e(*command, chdir: fixture_project.root.to_s)
    end

    expect(status.exitstatus).to eq(1)
    expect(output).to include('gem alpha 1.0.0: GPL-3.0-only')
  end

  it 'checks the Gemfile given by BUNDLE_GEMFILE' do
    fixture_project.add_configuration("permitted_licenses:\n  MIT:\n")
    fixture_project.add_gem('alpha', licenses: ['MIT'])
    fixture_project.add_gem('beta', licenses: ['GPL-3.0-only'])
    fixture_project.write('Gemfile', "gem 'alpha', path: 'gems/alpha'\n")
    fixture_project.write('Gemfile.next', "gem 'beta', path: 'gems/beta'\n")

    output, status = Bundler.with_unbundled_env do
      Open3.capture2e({ 'BUNDLE_GEMFILE' => 'Gemfile.next' }, *command, chdir: fixture_project.root.to_s)
    end

    expect(status.exitstatus).to eq(1)
    expect(output).to include('gem beta 1.0.0: GPL-3.0-only')
  end

end
