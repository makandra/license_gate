module LicenseGate

  # A gem or npm package (`ecosystem` is an Ecosystem) with licenses as its package manager reports them.
  Package = Data.define(:ecosystem, :name, :version, :licenses) do

    def license_strings
      reported_licenses = licenses.empty? ? [LicenseString::UNKNOWN] : licenses
      reported_licenses.map { |license| LicenseString.new(license) }
    end

    def to_s
      "#{ecosystem} #{name} #{version}"
    end

  end

end
