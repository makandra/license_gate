module LicenseGate

  # One license as a package manager reports it, e.g. `MIT` or `(MIT OR Apache-2.0)`.
  # An expression may combine licenses with either `OR` or `AND`; anything more complex is only permitted when listed verbatim.
  class LicenseString

    UNKNOWN = 'Unknown'.freeze

    def initialize(string)
      @string = string
    end

    def permitted?(permitted_licenses)
      permitted_names = permitted_licenses.to_set { |license| normalize(license) }
      permitted_names.include?(normalize(@string)) || expression_permitted?(permitted_names)
    end

    def unsupported?
      expression.match?(/[()]/) || (expression.include?(' OR ') && expression.include?(' AND '))
    end

    def unknown?
      normalize(@string) == normalize(UNKNOWN)
    end

    def to_s
      @string
    end

    private

    def expression_permitted?(permitted_names)
      if unsupported?
        false
      elsif expression.include?(' AND ')
        terms(' AND ').all? { |term| permitted_names.include?(term) }
      else
        terms(' OR ').any? { |term| permitted_names.include?(term) }
      end
    end

    # Splits before normalizing, which would turn ` OR ` into `-or-`.
    # Keeps empty terms, so an operator without licenses (like `( AND )`) is never permitted.
    def terms(operator)
      expression.split(operator, -1).map { |term| normalize(term) }
    end

    def normalize(license)
      license.strip.tr(' ', '-').downcase
    end

    # String without one pair of enclosing parentheses.
    def expression
      stripped = @string.strip
      if stripped.start_with?('(') && stripped.end_with?(')')
        stripped[1...-1]
      else
        stripped
      end
    end

  end

end
