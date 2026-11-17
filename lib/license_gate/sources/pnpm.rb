module LicenseGate
  module Sources

    # npm packages as reported by `pnpm licenses list`.
    # Note that it only knows installed packages.
    class Pnpm

      LOCKFILE = 'pnpm-lock.yaml'.freeze

      # The pnpm option leaving out each group.
      OPTIONS = {
        'devDependencies' => '--prod',
        'optionalDependencies' => '--no-optional',
      }.freeze

      def initialize(root, ignored_groups:)
        @root = root
        @ignored_groups = ignored_groups
      end

      def packages
        # pnpm records every install in this file. Without installed packages, it would report every license as `Unknown`.
        raise PnpmError, "#{LOCKFILE} found, but packages are not installed; run `pnpm install` first" unless @root.join('node_modules/.modules.yaml').exist?

        output = list_licenses
        # Older pnpm versions answer `--json` with this text when they find no packages.
        return [] if output.start_with?('No licenses in packages found')

        licenses = JSON.parse(output)
        entries = licenses.values.flatten
        entries.flat_map do |entry|
          versions = entry.fetch('versions') do
            # pnpm before 9 reports a single version instead.
            raise PnpmError, 'unexpected output from `pnpm licenses list`; pnpm 9 or later is required'
          end

          versions.map do |version|
            Package.new(
              ecosystem: Ecosystem::NPM,
              name: entry['name'],
              version:,
              licenses: [entry['license']],
            )
          end
        end
      end

      private

      def list_licenses
        # Without `--recursive`, pnpm 12 lists only the root project of a workspace.
        command = ['pnpm', 'licenses', 'list', '--json', '--recursive', *@ignored_groups.map { |group| OPTIONS.fetch(group) }]

        # Binary mode keeps non-ASCII package metadata readable under any locale; JSON is parsed as UTF-8.
        output, error, status = Open3.capture3(*command, chdir: @root.to_s, binmode: true)

        if status.success?
          output
        else
          # pnpm before 12 reports errors as JSON on stdout.
          details = error.empty? ? output : error
          raise PnpmError, "`#{command.join(' ')}` failed:\n#{details}"
        end
      rescue Errno::ENOENT
        raise PnpmError, "#{LOCKFILE} found, but pnpm is not installed"
      end

    end

  end
end
