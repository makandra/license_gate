module LicenseGate
  class Configuration

    DEFAULT_PATH = 'config/license_gate.yml'.freeze

    LicenseException = Data.define(:packages, :licenses) do

      def applies_to?(package)
        packages
          .fetch(package.ecosystem)
          .include?(package.name)
      end

    end

    attr_reader :ignored_bundler_groups, :ignored_npm_groups

    def self.load(path, display_path)
      data = read(path, display_path)
      begin
        new(data)
      rescue ConfigurationError => e
        raise ConfigurationError, "#{display_path}: #{e.message}"
      end
    end

    def self.read(path, display_path)
      data = YAML.safe_load_file(path, aliases: true)
      raise ConfigurationError, "#{display_path} is empty" unless data

      data
    rescue Errno::ENOENT
      raise ConfigurationError, "#{display_path} not found"
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "#{display_path} is not valid YAML: #{e.problem} (line #{e.line}, column #{e.column})"
    rescue Psych::Exception => e
      raise ConfigurationError, "#{display_path} is not valid YAML: #{e.message}"
    end
    private_class_method :read

    def initialize(data)
      assert_hash(data)
      assert_keys(data, %w[permitted_licenses license_exceptions ignored_groups])
      @permitted_licenses = load_permitted_licenses(data.fetch('permitted_licenses', {}))
      @license_exceptions = load_license_exceptions(data.fetch('license_exceptions', []))
      load_ignored_groups(data.fetch('ignored_groups', {}))
    end

    def permitted_licenses_for(package)
      exceptions = @license_exceptions.select { |exception| exception.applies_to?(package) }
      @permitted_licenses + exceptions.flat_map(&:licenses)
    end

    private

    def load_permitted_licenses(permitted_licenses)
      assert_hash(permitted_licenses, at: 'permitted_licenses')
      permitted_licenses.each do |license, reason|
        unless license.is_a?(String)
          raise ConfigurationError, "key #{license.inspect} in permitted_licenses must be a String, but is #{license.class}"
        end

        assert_reason(reason, at: "permitted_licenses.#{license}")
      end
      permitted_licenses.keys
    end

    def load_license_exceptions(license_exceptions)
      unless license_exceptions.is_a?(Array)
        raise ConfigurationError, "license_exceptions must be an Array, but is #{license_exceptions.inspect}"
      end

      license_exceptions.map.with_index do |exception, index|
        load_license_exception(exception, at: "license_exceptions[#{index}]")
      end
    end

    def load_license_exception(exception, at:)
      assert_hash(exception, at:)
      assert_keys(exception, %w[gems npm_packages licenses why], at:)
      unless names?(exception['licenses'])
        raise ConfigurationError, "#{at}.licenses must be a non-empty Array of Strings, but is #{exception['licenses'].inspect}"
      end
      unless package_lists?(exception)
        raise ConfigurationError, "#{at} must list at least one package in gems or npm_packages (Arrays of Strings)"
      end

      assert_reason(exception['why'], at: "#{at}.why")
      LicenseException.new(
        packages: {
          Ecosystem::GEM => Array(exception['gems']),
          Ecosystem::NPM => Array(exception['npm_packages']),
        },
        licenses: exception['licenses'],
      )
    end

    def load_ignored_groups(ignored_groups)
      assert_hash(ignored_groups, at: 'ignored_groups')
      assert_keys(ignored_groups, %w[bundler npm], at: 'ignored_groups')
      @ignored_bundler_groups = ignored_groups.fetch('bundler', [])
      @ignored_npm_groups = ignored_groups.fetch('npm', [])
      unless strings?(@ignored_bundler_groups)
        raise ConfigurationError, "ignored_groups.bundler must be an Array of Strings, but is #{@ignored_bundler_groups.inspect}"
      end
      unless npm_groups?(@ignored_npm_groups)
        raise ConfigurationError, "ignored_groups.npm may only list #{npm_groups.join(' and ')}, but is #{@ignored_npm_groups.inspect}"
      end
    end

    def assert_hash(value, at: 'the configuration')
      raise ConfigurationError, "#{at} must be a Hash, but is #{value.inspect}" unless value.is_a?(Hash)
    end

    def assert_keys(hash, keys, at: 'the configuration')
      unknown_keys = hash.keys - keys
      raise ConfigurationError, "unknown key #{unknown_keys.first.inspect} in #{at} (expected one of #{keys.join(', ')})" unless unknown_keys.empty?
    end

    def assert_reason(reason, at:)
      raise ConfigurationError, "reason at #{at} must be a String, true or empty, but is #{reason.inspect}" unless reason?(reason)
    end

    def reason?(value)
      value.nil? || value == true || value.is_a?(String)
    end

    def strings?(value)
      value.is_a?(Array) && value.all?(String)
    end

    def names?(value)
      strings?(value) && value.any?
    end

    # Either list may be empty, as long as the exception names a package.
    def package_lists?(exception)
      lists = exception.values_at('gems', 'npm_packages').compact
      lists.all? { |list| strings?(list) } && lists.flatten.any?
    end

    # Groups an npm package manager can leave out: pnpm can leave out all of them, Yarn checks its own.
    def npm_groups
      Sources::Pnpm::OPTIONS.keys
    end

    def npm_groups?(value)
      strings?(value) && (value - npm_groups).empty?
    end

  end
end
