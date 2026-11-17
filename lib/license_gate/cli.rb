module LicenseGate
  class CLI

    module ExitCode
      # All licenses are permitted, or help or version was shown.
      SUCCESS = 0

      # Some packages use licenses that are not permitted.
      VIOLATIONS = 1

      # The check could not run, e.g. because of invalid configuration.
      ERROR = 2
    end

    def initialize(arguments, out: $stdout, err: $stderr, gemfile: nil, lockfile: nil)
      @arguments = arguments
      @out = out
      @err = err
      @gemfile = gemfile
      @lockfile = lockfile
    end

    def run
      options = {}
      parser = option_parser
      unexpected_arguments = parser.parse(@arguments, into: options)

      if unexpected_arguments.any?
        raise UsageError, "unexpected argument #{unexpected_arguments.first.inspect}"
      elsif options[:help]
        @out.puts parser
        ExitCode::SUCCESS
      elsif options[:version]
        @out.puts VERSION
        ExitCode::SUCCESS
      else
        check(options[:config], all_packages: options[:report])
      end
    rescue StandardError => e
      @err.puts "license_gate: #{e.message}"
      ExitCode::ERROR
    end

    private

    def option_parser
      OptionParser.new do |parser|
        parser.banner = 'Usage: license_gate [options]'
        parser.on('--config PATH', "Configuration file, defaults to #{Configuration::DEFAULT_PATH}")
        parser.on('--report', 'List all packages with their licenses')
        parser.on('--version', 'Show version')
        parser.on('-h', '--help', 'Show this help')
      end
    end

    def check(config, all_packages:)
      # Bundler's defaults follow `BUNDLE_GEMFILE`, and find `gems.rb` with `gems.locked`.
      gemfile = @gemfile || ::Bundler.default_gemfile
      lockfile = @lockfile || ::Bundler.default_lockfile
      configuration_path = config || gemfile.dirname.join(Configuration::DEFAULT_PATH)
      display_path = config || Configuration::DEFAULT_PATH
      configuration = Configuration.load(configuration_path, display_path)
      result = Check.new(configuration, gemfile:, lockfile:).run
      report(result, display_path, all_packages:)
    end

    def report(result, display_path, all_packages:)
      @out.puts "npm packages: not checked (no #{Sources::Pnpm::LOCKFILE})" unless result.npm_checked
      listed_packages = all_packages ? result.packages : result.violations
      if listed_packages.any?
        listed_packages.each { |package| @out.puts package_line(package, result) }
        @out.puts
      end

      if result.violations.empty?
        @out.puts "All #{result.packages.size} packages use permitted licenses (#{counts(result)})."
        ExitCode::SUCCESS
      else
        @out.puts "#{result.violations.size} of #{result.packages.size} packages use licenses that are not permitted."
        @out.puts "Permit a license in #{display_path}, or add a license exception with a reason."
        ExitCode::VIOLATIONS
      end
    end

    def package_line(package, result)
      if result.violations.include?(package)
        violation(package)
      else
        "✓ #{package}: #{package.license_strings.join(' OR ')}"
      end
    end

    def violation(package)
      licenses = package.license_strings
      line = "✗ #{package}: #{licenses.join(' OR ')}"
      line << ' (unsupported expression)' if licenses.any?(&:unsupported?)
      line << ' (no license found)' if licenses.any?(&:unknown?)
      line
    end

    def counts(result)
      counts = result.packages.map(&:ecosystem).tally
      gem_count = counts.fetch(Ecosystem::GEM, 0)
      npm_count = counts.fetch(Ecosystem::NPM, 0)

      "#{gem_count} gems, #{npm_count} npm packages"
    end

  end
end
