module LicenseGate
  module Sources

    class Command

      def initialize(chdir:, error_class:)
        @chdir = chdir
        @error_class = error_class
      end

      # Returns standard output.
      def run(*command)
        # Binary mode keeps non-ASCII package metadata readable under any locale; JSON is parsed as UTF-8.
        output, error, status = Open3.capture3(*command, chdir: @chdir.to_s, binmode: true)

        if status.success?
          output
        else
          # Package managers report errors on stdout or stderr, depending on their version (e.g. pnpm before 12 on stdout).
          raise @error_class, "`#{command.join(' ')}` failed:\n#{output}#{error}"
        end
      end

    end

  end
end
