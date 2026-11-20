module LicenseGate
  module Sources

    # npm packages as reported by `yarn licenses list`, which the plugin yarn-plugin-licenses adds to Yarn 2 and later.
    class Yarn

      LOCKFILE = 'yarn.lock'.freeze

      PLUGIN_URL = 'https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.0/bundles/@yarnpkg/plugin-licenses.js'.freeze

      # Yarn 2 cannot run the command of later plugin releases.
      YARN_2_PLUGIN_URL = 'https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.6.0/bundles/@yarnpkg/plugin-licenses.js'.freeze

      # The plugin's option leaving out each group.
      OPTIONS = {
        'devDependencies' => '--production',
      }.freeze

      def initialize(root, ignored_groups:)
        @root = root
        @ignored_groups = ignored_groups
      end

      def packages
        versions = lockfile_versions
        # A package appears under several locators, e.g. as a `file:` dependency of two workspaces.
        packages = list_licenses.each_line.flat_map do |line|
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

      def list_licenses
        options = @ignored_groups.map do |group|
          OPTIONS.fetch(group) { raise ConfigurationError, "ignored_groups.npm: Yarn cannot leave out #{group}" }
        end
        command = ['yarn', 'licenses', 'list', '--json', '--recursive', *options]

        # Binary mode keeps non-ASCII package metadata readable under any locale; JSON is parsed as UTF-8.
        output, error, status = Open3.capture3(*command, chdir: @root.to_s, binmode: true)

        if status.success?
          output
        elsif output.include?(%(Couldn't find a script named "licenses"))
          raise YarnError, "#{LOCKFILE} found, but Yarn lacks the plugin yarn-plugin-licenses; " \
            "add it with `yarn plugin import #{PLUGIN_URL}` (with Yarn 2: `yarn plugin import #{YARN_2_PLUGIN_URL}`)"
        else
          # Yarn reports its errors on stdout.
          raise YarnError, "`#{command.join(' ')}` failed:\n#{output}#{error}"
        end
      rescue Errno::ENOENT
        raise YarnError, "#{LOCKFILE} found, but Yarn is not installed"
      end

    end

  end
end
