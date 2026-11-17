# A throwaway project with a Gemfile of local path gems, a configuration file and output for the fake pnpm.
class FixtureProject

  attr_reader :root

  def initialize
    @root = Pathname(Dir.mktmpdir('license_gate'))
    @gemfile_content = ''
    write('Gemfile', @gemfile_content)
  end

  def add_gem(name, licenses:, group: nil)
    write("gems/#{name}/#{name}.gemspec", <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = #{name.inspect}
        spec.version = '1.0.0'
        spec.authors = ['Fixture']
        spec.summary = 'Fixture gem'
        spec.licenses = #{licenses.inspect}
      end
    RUBY
    declaration = "gem #{name.inspect}, path: 'gems/#{name}'"
    declaration = "group #{group.inspect} do\n  #{declaration}\nend" if group
    @gemfile_content += "#{declaration}\n"
    write('Gemfile', @gemfile_content)
  end

  def add_configuration(yaml)
    write('config/license_gate.yml', yaml)
  end

  # Takes licenses with package names and their versions, e.g. `{ 'MIT' => { 'left-pad' => ['1.3.0'] } }`.
  def add_npm_packages(licenses)
    pnpm_output = licenses.to_h do |license, packages|
      [license, packages.map { |name, versions| { 'name' => name, 'versions' => versions, 'license' => license } }]
    end
    write('pnpm-lock.yaml', '')
    write('node_modules/.modules.yaml', '')
    write('fake-pnpm-output.json', JSON.generate(pnpm_output))
  end

  def fail_pnpm(stdout: '', stderr: '')
    write('fake-pnpm-stdout', stdout)
    write('fake-pnpm-stderr', stderr)
  end

  def gemfile
    root.join('Gemfile')
  end

  def lockfile
    root.join('Gemfile.lock')
  end

  def pnpm_arguments
    root.join('fake-pnpm-arguments').read.split
  end

  def write(path, content)
    file = root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  def remove
    FileUtils.remove_entry(root)
  end

end

module FixtureProjectHelpers

  def fixture_project
    @fixture_project ||= FixtureProject.new
  end

end

RSpec.configure do |config|
  config.include FixtureProjectHelpers
  config.after { @fixture_project&.remove }
end
