RSpec.describe 'license_gate with a real Yarn Classic' do

  include_context 'with a real package manager', 'yarn', [1], 'Yarn Classic (1)', fixture: 'yarn_classic'

  def install
    output, status = run('yarn', 'install')
    raise "yarn install failed:\n#{output}" unless status.success?
  end

  it_behaves_like 'a check with a real Yarn'

  # Like a fresh checkout of a project that does not commit its packages.
  # Yarn Classic then reads the packages on its own, so that no install is needed.
  context 'when packages are not installed' do
    before do
      FileUtils.rm_rf(project.glob('{node_modules,projects/*/node_modules}'))
    end

    it_behaves_like 'a check with a real Yarn'
  end

end
