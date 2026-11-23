# Runs the executable against a real package manager, which all other specs replace with spec/fixtures/bin.
#
# A spec covers some major versions of its package manager, and runs when one of them is on PATH.
#
# Specs including this define `install`, which installs the packages of the copied fixture.
RSpec.shared_context 'with a real package manager' do |executable, major_versions, description, fixture: executable|

  # Inside this repository, so that a mise shim picks the version of its mise.toml, not a global one.
  let(:project) do
    tmp = Pathname(File.expand_path('../../tmp', __dir__))
    tmp.mkpath
    Pathname(Dir.mktmpdir("license_gate_#{executable}", tmp))
  end
  let(:command) { [RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), File.expand_path('../../exe/license_gate', __dir__)] }
  # Further environment variables for every command, e.g. package manager settings.
  let(:env) { {} }
  let(:major_version) do
    output, status = run(executable, '--version')
    Gem::Version.new(output.strip).segments.first if status.success?
  rescue Errno::ENOENT
    nil
  end

  before do
    variable = "TEST_#{executable.upcase}"
    if ENV.key?(variable)
      tested_version = Integer(ENV.fetch(variable))
      skip "#{variable}=#{tested_version} is tested by another spec" unless major_versions.include?(tested_version)
      unless major_version == tested_version
        found = if major_version
          "#{executable} #{major_version}"
        else
          "no #{executable}"
        end
        raise "#{variable}=#{tested_version}, but #{found} is on PATH"
      end
    elsif ENV['CI']
      skip "#{variable} is not set, so this CI job does not test #{executable}"
    else
      skip "needs #{description} on PATH" unless major_versions.include?(major_version)
    end

    # Copies each entry on its own, so that links to spec/fixtures/npm/shared are followed.
    # Links further down would be copied as links, so they may only sit at the top level of a fixture.
    FileUtils.cp_r(Pathname(File.expand_path("../fixtures/npm/#{fixture}", __dir__)).children, project)
    install
  end

  after do
    FileUtils.remove_entry(project)
  end

  # Without a UTF-8 locale, as package managers report non-ASCII package authors.
  def run(*arguments)
    output, status = Bundler.with_unbundled_env do
      Open3.capture2e({ 'PATH' => REAL_PATH, 'LC_ALL' => 'C', **env }, *arguments, chdir: project.to_s)
    end
    [output.force_encoding(Encoding::UTF_8), status]
  end

end
