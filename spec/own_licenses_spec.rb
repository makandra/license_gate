# Checks this gem's own dependencies against config/license_gate.yml, as we recommend for any project.
RSpec.describe 'licenses of this gem' do

  it 'are all permitted' do
    out = StringIO.new
    err = StringIO.new

    exit_code = LicenseGate::CLI.new([], out:, err:).run

    expect(exit_code).to eq(0), out.string + err.string
  end

end
