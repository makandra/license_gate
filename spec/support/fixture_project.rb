# A throwaway project with a Gemfile of local path gems, a configuration file and output for the fake pnpm and yarn.
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
    write('fake-output', JSON.generate(pnpm_output))
  end

  # Takes package locators by license, e.g. `{ 'MIT' => ['left-pad@npm:1.3.0'] }`, and the versions the lockfile lists for locators.
  def add_yarn_packages(licenses, versions = {})
    lockfile = versions.to_h { |locator, version| [locator, { 'version' => version, 'resolution' => locator }] }
    yarn_output = licenses.map do |license, locators|
      "#{JSON.generate('value' => license, 'children' => locators.to_h { |locator| [locator, {}] })}\n"
    end
    write('yarn.lock', YAML.dump({ '__metadata' => { 'version' => 8 } }.merge(lockfile)))
    write('fake-output', yarn_output.join)
  end

  def fail_package_manager(stdout: '', stderr: '')
    write('fake-stdout', stdout)
    write('fake-stderr', stderr)
  end

  def gemfile
    root.join('Gemfile')
  end

  def lockfile
    root.join('Gemfile.lock')
  end

  def package_manager_arguments
    root.join('fake-arguments').read.split
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
