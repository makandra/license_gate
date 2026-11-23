RSpec.describe 'license_gate with a real Yarn 4' do

  include_context 'with a real package manager', 'yarn', 4.., 'Yarn 4 or later', fixture: 'yarn_berry'

  def install
    import_plugin
    install_packages
  end

  # As the README tells users.
  def import_plugin
    output, status = run('yarn', 'plugin', 'import', 'https://raw.githubusercontent.com/mhassan1/yarn-plugin-licenses/v0.15.1/bundles/@yarnpkg/plugin-licenses.js')
    raise "yarn plugin import failed:\n#{output}" unless status.success?
  end

  def install_packages
    output, status = run('yarn', 'install')
    raise "yarn install failed:\n#{output}" unless status.success?
  end

  %w[node-modules pnp].each do |linker|
    context "with nodeLinker: #{linker}" do
      let(:env) { { 'YARN_NODE_LINKER' => linker } }

      it_behaves_like 'a check with a real Yarn'

      # Like a fresh checkout of a project that does not commit its packages.
      it 'fails when packages are not installed' do
        FileUtils.rm_rf(project.glob('{node_modules,projects/*/node_modules,.pnp.*,.yarn/cache,.yarn/unplugged,.yarn/install-state.gz}'))
        project.join('config').mkpath
        project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

        output, status = run(*command)

        expect(status.exitstatus).to eq(2), output
        expect(output).to include('`yarn licenses list --json --recursive` failed')
      end
    end
  end

  context 'without the plugin' do
    def install
      install_packages
    end

    it 'fails with a hint' do
      project.join('config').mkpath
      project.join('config/license_gate.yml').write("permitted_licenses:\n  MIT:\n")

      output, status = run(*command)

      expect(status.exitstatus).to eq(2), output
      expect(output).to include('Yarn lacks the plugin yarn-plugin-licenses')
    end
  end

end
