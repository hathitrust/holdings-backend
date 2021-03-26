# frozen_string_literal: true

require_relative '../concordance_validation'
include ConcordanceValidation

describe 'numbers_tab_numbers' do
  it 'raises an error if it isn\'t numbers-tab-numbers throughout' do
    expect do
      Concordance.numbers_tab_numbers(
        'spec/data/letters_tab_letters.tsv'
      )
    end.to \
      raise_error('Invalid format. 2 line(s) are malformed.')
  end

  it 'raises an error if it isn\'t numbers-tab-numbers throughout' do
    expect { Concordance.numbers_tab_numbers('spec/data/cycles.tsv') }.not_to \
      raise_error
  end
end

describe 'terminal_ocn' do
  it 'can find root ocns' do
    chained = Concordance.new('spec/data/chained.tsv')
    expect(chained.terminal_ocn(1)).to eq(3)
  end

  it 'complains if there are multiple terminal ocns' do
    multi = Concordance.new('spec/data/multiple_terminal.tsv')
    expect { multi.terminal_ocn(1) }.to \
      raise_error('OCN:1 resolves to multiple ocns: 2, 3')
  end
end

describe 'Concordance.new' do
  it 'builds a basic concordance structure' do
    expect(Concordance.new('spec/data/chained.tsv').raw_to_resolved).to \
      eq(1 => [2], 2 => [3])
  end

  it 'handles gzipped files' do
    expect(Concordance.new('spec/data/chained.tsv.gz').raw_to_resolved).to \
      eq(1 => [2], 2 => [3])
  end
end

describe 'compile_sub_graph' do
  it 'compiles a list of all edges when given an ocn' do
    disconnected = Concordance.new('spec/data/disconnected.tsv')
    expect(disconnected.compile_sub_graph(2)).to eq([{ 1 => [2, 3], 2 => [3] },
                                                     { 2 => [1], 3 => [1, 2] }])
  end
end

describe 'detect_cycles' do
  it 'detects cycles' do
    cycles = Concordance.new('spec/data/cycles.tsv')
    sub = cycles.compile_sub_graph(1)
    expect { cycles.detect_cycles(*sub) }.to \
      raise_error('Cycles: 1, 2, 3')
  end

  it 'detects more indirect cycles' do
    indirect_cycles = Concordance.new('spec/data/indirect_cycles.tsv')
    sub = indirect_cycles.compile_sub_graph(2)
    expect { indirect_cycles.detect_cycles(*sub) }.to \
      raise_error('Cycles: 2, 3')
  end

  it 'detects cycles in noncontiguous graphs' do
    cycles = Concordance.new('spec/data/noncontiguous_cycle_graph.tsv')
    sub = cycles.compile_sub_graph(1)
    expect { cycles.detect_cycles(*sub) }.to \
      raise_error('Cycles: 2, 3, 4, 5')
  end

  it 'returns a long list of ocns if no cycles found' do
    noncycles = Concordance.new('spec/data/not_cycle_graph.tsv')
    sub = noncycles.compile_sub_graph(2)
    expect { noncycles.detect_cycles(*sub) }.to_not \
      raise_error
  end
end
