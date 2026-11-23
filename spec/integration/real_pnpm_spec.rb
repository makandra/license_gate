RSpec.describe 'license_gate with a real pnpm' do

  include_context 'with a real package manager', 'pnpm', 9.., 'pnpm 9 or later'

  def install
    output, status = run('pnpm', 'install', '--offline', '--no-frozen-lockfile')
    raise "pnpm install failed:\n#{output}" unless status.success?
  end

  it 'reports npm packages of all workspace projects whose licenses are not permitted' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(1)
    expect(output)
      .to match(/^✗ npm dev-package .*: GPL-3\.0-only$/)
      .and match(/^✗ npm optional-package .*: BSD-3-Clause$/)
      .and match(/^✗ npm sub-package .*: ISC$/)
      .and match(/^✗ npm unlicensed-package .*: Unknown \(no license found\)$/)
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

  it 'leaves out optionalDependencies when they are ignored' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n  ISC:\nignored_groups:\n  npm: [optionalDependencies]\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(1)
    expect(output)
      .to include('2 of 4 packages use licenses that are not permitted.')
      .and not_include('optional-package')
  end

end
