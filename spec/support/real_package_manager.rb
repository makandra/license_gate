# Runs the executable against a real package manager, which all other specs replace with spec/fixtures/bin.
# Skipped without a matching version on PATH, unless REAL_PNPM=required (as in CI).
# Specs including this define `install`, which installs the packages of the copied fixture.
RSpec.shared_context 'with a real package manager' do |executable, major_versions, description|

  # Inside this repository, so that a mise shim picks the version of its mise.toml.
  let(:project) do
    tmp = Pathname(File.expand_path('../../tmp', __dir__))
    tmp.mkpath
    Pathname(Dir.mktmpdir("license_gate_#{executable}", tmp))
  end
  let(:command) { [RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), File.expand_path('../../exe/license_gate', __dir__)] }
  let(:major_version) do
    output, status = run(executable, '--version')
    Gem::Version.new(output.strip).segments.first if status.success?
  rescue Errno::ENOENT
    nil
  end

  before do
    if major_versions.include?(major_version)
      # Packages for all package managers, then this one's project configuration.
      fixtures = File.expand_path('../fixtures', __dir__)
      FileUtils.cp_r("#{fixtures}/npm_workspace/.", project)
      FileUtils.cp_r("#{fixtures}/#{executable}_workspace/.", project)
      install
    elsif ENV["REAL_#{executable.upcase}"] == 'required'
      raise "needs #{description} on PATH"
    else
      skip "needs #{description} on PATH"
    end
  end

  after do
    FileUtils.remove_entry(project)
  end

  # Without a UTF-8 locale, as package managers report non-ASCII package authors.
  def run(*arguments)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e({ 'PATH' => REAL_PATH, 'LC_ALL' => 'C' }, *arguments, chdir: project.to_s)
    end
    [output.force_encoding(Encoding::UTF_8), status]
  end

end
