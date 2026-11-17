require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
  minimum_coverage line: 100, branch: 100
end

require 'license_gate'
require 'stringio'
require 'tmpdir'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

# Specs run the fake pnpm from spec/fixtures/bin, except for spec/integration, which needs a real one.
REAL_PATH = ENV.fetch('PATH')
ENV['PATH'] = [File.expand_path('fixtures/bin', __dir__), REAL_PATH].join(File::PATH_SEPARATOR)

Bundler.ui = Bundler::UI::Silent.new

RSpec::Matchers.define_negated_matcher :not_include, :include

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  # CI installs this gem's bundle in deployment mode, which refuses to resolve fixture projects without a lockfile.
  config.around do |example|
    Bundler.settings.temporary(frozen: false, deployment: false) { example.run }
  end
end
