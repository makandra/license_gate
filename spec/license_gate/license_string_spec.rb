RSpec.describe LicenseGate::LicenseString do

  def permitted?(string, licenses)
    described_class.new(string).permitted?(licenses)
  end

  describe '#permitted?' do
    it 'is true for a permitted license' do
      expect(permitted?('MIT', ['MIT'])).to be(true)
    end

    it 'is false for a license that is not permitted' do
      expect(permitted?('GPL-3.0-only', ['MIT'])).to be(false)
    end

    it 'ignores case and treats spaces as dashes' do
      expect(permitted?('bsd 2-clause', ['BSD-2-Clause'])).to be(true)
    end

    it 'ignores surrounding whitespace' do
      expect(permitted?(' MIT ', ['ISC ', ' MIT'])).to be(true)
    end

    it 'is true for an OR expression with one permitted license' do
      expect(permitted?('(WTFPL OR MIT)', ['MIT'])).to be(true)
    end

    it 'is false for an OR expression without a permitted license' do
      expect(permitted?('(WTFPL OR GPL-3.0-only)', ['MIT'])).to be(false)
    end

    it 'is true for an AND expression whose licenses are all permitted' do
      expect(permitted?('(Apache-2.0 AND BSD-3-Clause)', %w[Apache-2.0 BSD-3-Clause])).to be(true)
    end

    it 'is false for an AND expression with a license that is not permitted' do
      expect(permitted?('(Apache-2.0 AND GPL-3.0-only)', ['Apache-2.0'])).to be(false)
    end

    it 'is false for an operator without licenses' do
      expect(permitted?('( AND )', [])).to be(false)
    end

    it 'only treats uppercase OR and AND as operators' do
      expect(permitted?('GPL-2.0 or later', ['GPL-2.0-or-later'])).to be(true)
    end

    it 'is false for an expression mixing OR and AND, even if all its licenses are permitted' do
      expect(permitted?('MIT OR Apache-2.0 AND Zlib', %w[MIT Apache-2.0 Zlib])).to be(false)
    end

    it 'is false for a nested expression, even if all its licenses are permitted' do
      expect(permitted?('(MIT AND Zlib) OR Apache-2.0', %w[MIT Apache-2.0 Zlib])).to be(false)
    end

    it 'is true for any string permitted verbatim' do
      expect(permitted?('(MIT AND Zlib) OR Apache-2.0', ['(MIT AND Zlib) OR Apache-2.0'])).to be(true)
    end

    it 'treats a license with an exception as a license of its own' do
      expect(permitted?('Apache-2.0 WITH LLVM-exception', ['Apache-2.0'])).to be(false)
    end
  end

  describe '#unsupported?' do
    it 'is true for an expression mixing OR and AND' do
      expect(described_class.new('MIT OR Apache-2.0 AND Zlib').unsupported?).to be(true)
    end

    it 'is true for a nested expression' do
      expect(described_class.new('(MIT AND Zlib) OR Apache-2.0').unsupported?).to be(true)
    end

    it 'is false for an expression with a single operator' do
      expect(described_class.new('(MIT OR Apache-2.0)').unsupported?).to be(false)
    end
  end

  describe '#unknown?' do
    it 'is true for Unknown, as reported for a package without a license' do
      expect(described_class.new('unknown').unknown?).to be(true)
    end

    it 'is false for a license' do
      expect(described_class.new('MIT').unknown?).to be(false)
    end
  end

  describe '#to_s' do
    it 'returns the string as reported' do
      expect(described_class.new('(MIT OR Apache-2.0)').to_s).to eq('(MIT OR Apache-2.0)')
    end

    it 'returns Unknown however a package manager spells it' do
      expect(described_class.new('UNKNOWN').to_s).to eq('Unknown')
    end
  end

end
