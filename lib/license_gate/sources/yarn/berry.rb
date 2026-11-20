module LicenseGate
  module Sources
    class Yarn

      # Packages from the output of the plugin yarn-plugin-licenses for Yarn 2 and later.
      class Berry

        def initialize(root)
          @root = root
        end

        def packages(output)
          versions = lockfile_versions
          # A package appears under several locators, e.g. as a `file:` dependency of two workspaces.
          packages = output.each_line.flat_map do |line|
            entry = JSON.parse(line)
            # Workspaces are the project itself, not its dependencies.
            locators = entry['children'].keys.grep_v(/@workspace:/)
            locators.map do |locator|
              Package.new(
                ecosystem: Ecosystem::NPM,
                name: locator[/\A@?[^@]+/],
                # Locators of packages with peer dependencies wrap the locator the lockfile lists, e.g. `debug@virtual:<hash>#npm:4.4.0`.
                version: versions.fetch(locator.sub(/@virtual:[^#]+#/, '@')),
                licenses: [entry['value']],
              )
            end
          end
          packages.uniq
        end

        private

        # Locators only carry a version for some protocols (not e.g. for `file:`), so versions come from the lockfile.
        def lockfile_versions
          entries = YAML.safe_load_file(@root.join(LOCKFILE)).except('__metadata')
          entries.values.to_h { |entry| [entry['resolution'], entry['version']] }
        end

      end

    end
  end
end
