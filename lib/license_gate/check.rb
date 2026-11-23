module LicenseGate
  class Check

    Result = Data.define(:packages, :violations, :npm_checked)

    DEPENDENCY_KEYS = %w[dependencies devDependencies optionalDependencies].freeze

    NPM_SOURCES = [Sources::Pnpm, Sources::YarnBerry, Sources::YarnClassic].freeze
    NPM_LOCKFILES = NPM_SOURCES.map { |source| source::LOCKFILE }.uniq.freeze

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

      responsible_sources = NPM_SOURCES.select { |source| source.responsible_for?(@root) }
      if responsible_sources.size > 1
        lockfiles = responsible_sources.map { |source| source::LOCKFILE }
        raise UnsupportedPackageManagerError, "found #{lockfiles.join(' and ')}; delete the lockfile of the package manager you no longer use"
      end

      @npm_source = if responsible_sources.any?
        responsible_sources.first.new(@root, ignored_groups: @configuration.ignored_npm_groups)
      elsif npm_dependencies?
        raise UnsupportedPackageManagerError,
          "package.json declares dependencies, but there is no #{NPM_LOCKFILES.join(' or ')} of a supported package manager"
      end
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
