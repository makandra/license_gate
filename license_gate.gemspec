require_relative 'lib/license_gate/version'

Gem::Specification.new do |spec|
  spec.name = 'license_gate'
  spec.version = LicenseGate::VERSION
  spec.authors = ['Arne Hartherz']
  spec.email = ['arne.hartherz@makandra.de']

  spec.summary = 'Checks licenses of your Bundler and pnpm dependencies against an allowlist'
  spec.description = 'Fails when a gem or npm package uses a license your project has not permitted. Further licenses can be allowed for specific packages only.'
  spec.homepage = 'https://github.com/makandra/license_gate'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true',
  }

  spec.files = Dir['lib/**/*.rb', 'exe/*', 'README.md', 'CHANGELOG.md', 'LICENSE']
  spec.bindir = 'exe'
  spec.executables = ['license_gate']
  spec.require_paths = ['lib']
end
