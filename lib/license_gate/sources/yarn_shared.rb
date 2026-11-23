module LicenseGate
  module Sources

    module YarnShared

      LOCKFILE = 'yarn.lock'.freeze

      # Leaving out specific groups in Yarn is done via arguments. Yarn only supports skipping `devDependencies`.
      OPTIONS = {
        'devDependencies' => '--production',
      }.freeze

      def initialize(root, ignored_groups:)
        @root = root
        @ignored_groups = ignored_groups
      end

      private

      def list_licenses(*options)
        Command
          .new(chdir: @root, error_class: YarnError)
          .run('yarn', 'licenses', 'list', '--json', *options, *group_options)
      rescue Errno::ENOENT
        raise YarnError, "#{LOCKFILE} found, but Yarn is not installed"
      end

      def group_options
        @ignored_groups.map do |group|
          OPTIONS.fetch(group) { raise ConfigurationError, "ignored_groups.npm: Yarn cannot leave out #{group}" }
        end
      end

    end

  end
end
