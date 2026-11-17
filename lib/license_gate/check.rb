module LicenseGate
  class Check

    Result = Data.define(:packages, :violations, :npm_checked)

    DEPENDENCY_KEYS = %w[dependencies devDependencies optionalDependencies].freeze

    def initialize(configuration, gemfile:, lockfile:)
      @configuration = configuration
      @gemfile = gemfile
      @lockfile = lockfile
      @root = gemfile.dirname
    end

    def run
      packages = sources
        .flat_map(&:packages)
        .sort_by { |package| [package.ecosystem, package.name, package.version] }
      violations = packages.reject { |package| permitted?(package) }

      Result.new(
        packages:,
        violations:,
        npm_checked: !!npm_source,
      )
    end

    private

    def sources
      @sources ||= [
        gem_source,
        npm_source,
      ].compact
    end

    def gem_source
      @gem_source ||= Sources::Bundler.new(@gemfile, @lockfile, ignored_groups: @configuration.ignored_bundler_groups)
    end

    def npm_source
      return @npm_source if defined?(@npm_source)

      @npm_source = if pnpm_project?
        Sources::Pnpm.new(@root, ignored_groups: @configuration.ignored_npm_groups)
      elsif npm_dependencies?
        raise UnsupportedPackageManagerError, "package.json declares dependencies, but there is no #{Sources::Pnpm::LOCKFILE}; only pnpm is supported"
      end
    end

    def pnpm_project?
      @root.join(Sources::Pnpm::LOCKFILE).exist?
    end

    def npm_dependencies?
      package_json = @root.join('package.json')
      if package_json.exist?
        dependency_lists = JSON.parse(package_json.read).values_at(*DEPENDENCY_KEYS).compact
        dependency_lists.any?(&:any?)
      else
        false
      end
    end

    # A gem lists licenses to choose from, so one permitted license is enough.
    def permitted?(package)
      permitted_licenses = @configuration.permitted_licenses_for(package)
      package.license_strings.any? { |license| license.permitted?(permitted_licenses) }
    end

  end
end
