require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec) { _1.verbose = false }
RuboCop::RakeTask.new(:rubocop)

task default: [:spec, :rubocop]
