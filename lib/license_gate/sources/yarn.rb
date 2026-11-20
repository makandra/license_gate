module LicenseGate
  module Sources

    # npm packages as reported by `yarn licenses list`.
    # Yarn 1 has the command built in, Yarn 2 and later get it from the plugin yarn-plugin-licenses.
    class Yarn

      LOCKFILE = 'yarn.lock'.freeze

      PLUGIN_URL = 'https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.0/bundles/@yarnpkg/plugin-licenses.js'.freeze

      # Yarn 2 cannot run the command of later plugin releases.
      YARN_2_PLUGIN_URL = 'https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.6.0/bundles/@yarnpkg/plugin-licenses.js'.freeze

      # The option leaving out each group.
      OPTIONS = {
        'devDependencies' => '--production',
      }.freeze

      def initialize(root, ignored_groups:)
        @root = root
        @ignored_groups = ignored_groups
      end

      def packages
        parser = legacy? ? Legacy : Berry
        parser.new(@root).packages(list_licenses)
      end

      private

      # Yarn 1 writes this line to its lockfiles, which have a format of their own.
      def legacy?
        @root.join(LOCKFILE).read.include?('# yarn lockfile v1')
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
