module LicenseGate
  module Sources

    # Gems of a project's lockfile, except those only needed by ignored groups.
    class Bundler

      def initialize(gemfile, lockfile, ignored_groups:)
        @gemfile = gemfile
        @lockfile = lockfile
        @ignored_groups = ignored_groups.map(&:to_sym)
      end

      def packages
        specs.map do |spec|
          # A gemspec setting `license = nil` reports `[nil]`.
          licenses = spec.licenses.compact

          Package.new(
            ecosystem: Ecosystem::GEM,
            name: spec.name,
            version: spec.version.to_s,
            licenses:,
          )
        end
      end

      private

      def specs
        definition = ::Bundler::Definition.build(@gemfile, @lockfile, nil)
        groups = definition.groups - @ignored_groups

        # When given no groups, `specs_for` returns gems of all groups.
        if groups.any?
          definition.specs_for(groups)
        else
          []
        end
      end

    end

  end
end
