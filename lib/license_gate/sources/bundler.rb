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
        definition = ::Bundler::Definition.build(@gemfile, @lockfile, nil)
        groups = definition.groups - @ignored_groups
        # `specs_for` returns gems of all groups when given no groups.
        specs = groups.any? ? definition.specs_for(groups) : []
        specs.map do |spec|
          # A gemspec setting `license = nil` reports `[nil]`.
          licenses = spec.licenses.compact
          Package.new(ecosystem: Ecosystem::GEM, name: spec.name, version: spec.version.to_s, licenses:)
        end
      end

    end

  end
end
