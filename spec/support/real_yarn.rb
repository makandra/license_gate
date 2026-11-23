# Examples for specs including 'with a real package manager' for Yarn.
RSpec.shared_examples 'a check with a real Yarn' do

  it 'reports npm packages of all workspaces whose licenses are not permitted' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(1), output
    expect(output)
      .to match(/^✗ npm dev-package 1\.0\.0: GPL-3\.0-only$/)
      .and match(/^✗ npm optional-package 1\.0\.0: BSD-3-Clause$/)
      .and match(/^✗ npm sub-package 1\.0\.0: ISC$/)
      .and match(/^✗ npm unlicensed-package 1\.0\.0: Unknown \(no license found\)$/)
      .and include('4 of 5 packages use licenses that are not permitted.')
  end

  it 'leaves out devDependencies when they are ignored' do
    project.join('config').mkpath
    project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n  ISC:\nignored_groups:\n  npm: [devDependencies]\n")

    output, status = run(*command)

    expect(status.exitstatus).to eq(1), output
    expect(output)
      .to include('2 of 4 packages use licenses that are not permitted.')
      .and not_include('dev-package')
  end

end
