module LicenseGate
  module Sources

    # npm packages as reported by `yarn licenses list` of Yarn 4.
    # Needs the Yarn plugin `yarn-plugin-licenses`.
    class YarnBerry

      include YarnShared

      # Yarn 2 and later write the format version of their lockfiles under this key.
      def self.responsible_for?(root)
        lockfile = root.join(LOCKFILE)
        lockfile.exist? && lockfile.read.include?('__metadata:')
      end

      def packages
        output = list_licenses('--recursive')
        versions = lockfile_versions

        packages = output.each_line.flat_map do |line|
          entry = JSON.parse(line)
          children = entry.fetch('children') do
            # Yarn Classic has a `yarn licenses list` of its own, which prints another format.
            raise YarnError, "unexpected output from `yarn licenses list`; this #{LOCKFILE} needs Yarn 4"
          end

          # Workspaces are the project itself, not its dependencies.
          locators = children.keys.grep_v(/@workspace:/)
          locators.map { |locator| package(locator, entry['value'], versions) }
        end

        # A package appears under several locators, e.g. as a `file:` dependency of two workspaces.
        packages.uniq
      rescue YarnError => error
        if error.message.include?(%(Couldn't find a script named "licenses"))
          raise YarnError, "#{LOCKFILE} found, but Yarn lacks the plugin yarn-plugin-licenses (see License Gate README for details)"
        else
          raise
        end
      end

      private

      def package(locator, license, versions)
        # Locators of packages with peer dependencies wrap the locator listed by the lockfile, e.g. `debug@virtual:<hash>#npm:4.4.0`.
        version_locator = locator.sub(/@virtual:[^#]+#/, '@')

        version = versions.fetch(version_locator) do
          raise YarnError, "`yarn licenses list` reports #{version_locator}, which #{LOCKFILE} lacks; run `yarn install`"
        end

        Package.new(
          ecosystem: Ecosystem::NPM,
          name: locator[/\A@?[^@]+/],
          version:,
          licenses: [license],
        )
      end

      # Locators only carry a version for some protocols (not e.g. for `file:`), so versions come from the lockfile.
      def lockfile_versions
        entries = YAML.safe_load_file(@root.join(LOCKFILE)).except('__metadata')
        entries.values.to_h { |entry| [entry['resolution'], entry['version']] }
      end

    end

  end
end
