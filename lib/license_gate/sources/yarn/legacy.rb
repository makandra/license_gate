module LicenseGate
  module Sources
    class Yarn

      # Packages from the output of Yarn 1, which has `yarn licenses list` built in.
      class Legacy

        def initialize(root)
          @root = root
        end

        def packages(output)
          table = output.each_line.map { |line| JSON.parse(line) }.find { |entry| entry['type'] == 'table' }
          workspaces = workspace_names_and_versions
          # Yarn 1 lists workspaces like dependencies, gathered by a package of its own.
          rows = table['data']['body'].reject do |name, version, *|
            workspaces.include?([name, version]) || name.start_with?('workspace-aggregator-')
          end
          rows.map do |name, version, license|
            Package.new(ecosystem: Ecosystem::NPM, name:, version:, licenses: [license])
          end
        end

        private

        def workspace_names_and_versions
          workspaces = read_json('package.json').fetch('workspaces', [])
          # Workspaces may also be configured as `{ "packages": [...], "nohoist": [...] }`.
          globs = workspaces.is_a?(Hash) ? workspaces.fetch('packages', []) : workspaces
          manifests = Dir.glob(globs.map { |glob| "#{glob}/package.json" }, base: @root.to_s)
          # Like Yarn, skips installed packages that a glob like `projects/**` matches.
          manifests.grep_v(%r{(\A|/)node_modules/}).map { |manifest| read_json(manifest).values_at('name', 'version') }
        end

        # Reads UTF-8 under any locale.
        def read_json(path)
          JSON.parse(@root.join(path).read(encoding: Encoding::UTF_8))
        end

      end

    end
  end
end
