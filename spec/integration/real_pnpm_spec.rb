# Runs the executable against a real pnpm, which all other specs replace with spec/fixtures/bin/pnpm.
# Skipped without pnpm 9 or later on PATH, unless REAL_PNPM=required (as in CI).
RSpec.describe 'license_gate with a real pnpm' do

  # Inside this repository, so that a mise shim picks the pnpm of its mise.toml.
  let(:project) do
    tmp = Pathname(File.expand_path('../../tmp', __dir__))
    tmp.mkpath
    Pathname(Dir.mktmpdir('license_gate_pnpm', tmp))
  end
  let(:command) { [RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), File.expand_path('../../exe/license_gate', __dir__)] }

  before do
    pnpm_version = real_pnpm_version
    if pnpm_version && pnpm_version >= Gem::Version.new('9')
      # Packages shared with other package managers, then pnpm's project configuration.
      fixtures = File.expand_path('../fixtures', __dir__)
      FileUtils.cp_r("#{fixtures}/npm_workspace/.", project)
      FileUtils.cp_r("#{fixtures}/pnpm_workspace/.", project)
      output, status = run('pnpm', 'install', '--offline', '--no-frozen-lockfile')
      raise "pnpm install failed:\n#{output}" unless status.success?
    elsif ENV['REAL_PNPM'] == 'required'
      raise 'needs pnpm 9 or later on PATH'
    else
      skip 'needs pnpm 9 or later on PATH'
    end
  end

  after do
    FileUtils.remove_entry(project)
  end

  def real_pnpm_version
    output, status = run('pnpm', '--version')
    Gem::Version.new(output.strip) if status.success?
  rescue Errno::ENOENT
    nil
  end

  # Without a UTF-8 locale, as pnpm reports non-ASCII package authors.
  def run(*arguments)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e({ 'PATH' => REAL_PATH, 'LC_ALL' => 'C' }, *arguments, chdir: project.to_s)
    end
    [output.force_encoding(Encoding::UTF_8), status]
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
