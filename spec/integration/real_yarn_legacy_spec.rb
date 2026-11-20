RSpec.describe 'license_gate with a real Yarn 1' do

  include_context 'with a real Yarn', [1], 'Yarn 1'

  it_behaves_like 'a check with a real Yarn'

end
