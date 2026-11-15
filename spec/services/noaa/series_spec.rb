# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::Series do
  it 'compares only exact timestamps, retains zero and leaves flagged or missing values as gaps' do
    observed = [{ timestamp: 1, value: 0, flags: '0,0,0,0' },
                { timestamp: 2, value: 1, flags: '0,1,0,0' },
                { timestamp: 3, value: nil }, { timestamp: 4, value: 4 }]
    predicted = [{ timestamp: 1, value: 0 }, { timestamp: 2, value: 0.5 },
                 { timestamp: 3, value: 0.5 }, { timestamp: 5, value: 0.5 }]
    expect(described_class.differences(observed, predicted).pluck(:value)).to eq([0, nil, nil, nil])
    expect(described_class.differences(observed, predicted, subordinate: true)).to eq([])
    expect(described_class.differences(observed, [])).to eq([])
  end

  it 'reads salinity and specific gravity from their documented fields and rejects nonfinite values' do
    row = { 't' => '2026-11-14 18:00', 's' => '32.5', 'g' => '1.024', 'v' => '999' }
    expect(described_class.observation(row, 'salinity')).to include(value: 32.5,
                                                                    specific_gravity: 1.024)
    expect(described_class.observation(row.merge('g' => 'Infinity'), 'salinity'))
      .to include(specific_gravity: nil)
    expect(described_class.observation(row.merge('s' => 'NaN'), 'salinity')).to include(value: nil)
  end

  it 'prefers enabled sensor duplicates and discovers derived salinity only for enabled conductivity' do
    rows = [{ 'name' => 'Conductivity', 'status' => 0 },
            { 'name' => 'Conductivity', 'status' => 1 }]
    expect(Noaa::Sensors.normalize(rows).pluck(:product)).to eq(%w[conductivity salinity])
    expect(Noaa::Sensors.normalize(rows).first[:enabled]).to be(true)
    expect(Noaa::Sensors.normalize(rows.first(1)).pluck(:product)).to eq(['conductivity'])
  end
end
