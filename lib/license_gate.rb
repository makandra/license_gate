require 'bundler'
require 'json'
require 'open3'
require 'optparse'
require 'yaml'

module LicenseGate

  # Prevents a check from running.
  Error = Class.new(StandardError)
  ConfigurationError = Class.new(Error)
  PnpmError = Class.new(Error)
  UnsupportedPackageManagerError = Class.new(Error)
  UsageError = Class.new(Error)
  YarnError = Class.new(Error)

end

require_relative 'license_gate/version'
require_relative 'license_gate/license_string'
require_relative 'license_gate/ecosystem'
require_relative 'license_gate/package'
require_relative 'license_gate/configuration'
require_relative 'license_gate/sources/bundler'
require_relative 'license_gate/sources/pnpm'
require_relative 'license_gate/sources/yarn'
require_relative 'license_gate/sources/yarn/berry'
require_relative 'license_gate/sources/yarn/legacy'
require_relative 'license_gate/check'
require_relative 'license_gate/cli'
