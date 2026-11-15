# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::NearbyBuoys do
  let(:station) { { 'latitude' => 37.8, 'longitude' => -122.5 } }
  let(:client) { Noaa::BuoyClient.new(cache: ActiveSupport::Cache::NullStore.new) }
  let(:xml) do
    '<stations><station id="46026" name="Nearby" lat="37.8" lon="-122.7" met="y" type="buoy"/>' \
      '<station id="46027" name="Far" lat="0" lon="0" met="y" type="buoy"/>' \
      '<station id="../xx" lat="37.8" lon="-122.7" met="y" type="buoy"/>' \
      '<station id="46028" lat="NaN" lon="0" met="y" type="buoy"/>' \
      '<station id="46029" lat="37.8" lon="-122.7" met="n"/></stations>'
  end
  let(:data) do
    "#YY MM DD hh mm WDIR WSPD GST WVHT DPD APD MWD PRES ATMP WTMP\n# units\n" \
      "2026 11 14 18 00 0 5 8 2 12 9 0 1013 10 0\n" \
      "2026 11 14 18 30 MM MM MM MM MM MM MM MM MM MM\n" \
      "2026 11 14 18 48 270 6 9 3 13 10 290 1012 11 1\n" \
      "2026 11 14 18 48 270 6 9 3 13 10 290 1012 11 1\n" \
      "2026 11 17 18 00 0 5 8 99 12 9 0 1013 10 0\n" \
      "2026 11 01 18 00 0 5 8 99 12 9 0 1013 10 0\n" \
      "2026 55 14 18 00 0 5 8 99 12 9 0 1013 10 0\n" \
      "short row\n"
  end

  before do
    travel_to(Time.utc(2026, 11, 14, 19))
    stub_request(:get, 'https://www.ndbc.noaa.gov/activestations.xml').to_return(body: xml)
    stub_request(:get, 'https://www.ndbc.noaa.gov/data/realtime2/46026.txt').to_return(body: data)
  end

  it 'selects nearby reporting instruments and preserves missing samples and real zeros' do
    result = described_class.new(station, units: 'metric', client:).call
    buoy = result[:buoys].sole
    expect(buoy[:series]['wave_height'].pluck(:value)).to eq([2.0, nil, 3.0])
    expect(buoy[:series]['water_temperature'].first[:value]).to eq(0.0)
    expect(buoy).to include(id: '46026', stale: false)
    expect(buoy[:distance_km]).to be_between(17, 18)
    expect(WebMock).not_to have_requested(:get, /46027|46028|46029/)
  end

  it 'converts SI buoy heights, winds and temperatures for US displays' do
    buoy = described_class.new(station, client:).call[:buoys].sole
    expect(buoy[:series]['wave_height'].first[:value]).to be_within(0.001).of(6.5617)
    expect(buoy[:series]['wind'].first[:value]).to be_within(0.001).of(9.7192)
    expect(buoy[:series]['water_temperature'].first[:value]).to eq(32.0)
    expect(buoy[:series]['wave_period'].first[:value]).to eq(12.0)
  end

  it 'flags stale data without calling it a current local station measurement' do
    travel_to(Time.utc(2026, 11, 14, 23))
    expect(described_class.new(station, client:).call[:buoys].sole[:stale]).to be(true)
  end

  it 'isolates missing and invalid buoy files' do
    stub_request(:get, /46026.txt/).to_return(status: 404)
    result = described_class.new(station, client:).call
    expect(result[:buoys]).to eq([])
    expect(result[:warnings].join).to include('46026')
    stub_request(:get, /46026.txt/).to_return(body: 'bad header')
    expect(described_class.new(station, client:).call[:warnings].join).to include('columns')
  end

  it 'does not invent values when all columns are missing' do
    stub_request(:get, /46026.txt/).to_return(body:
      "#YY MM DD hh mm WVHT\n# units\n2026 11 14 18 00 MM\n")
    expect(described_class.new(station, client:).call[:buoys]).to eq([])
  end

  it 'reports corrupt catalogs and network failures explicitly' do
    stub_request(:get, /activestations.xml/).to_return(body: '<broken>')
    expect { described_class.new(station, client:).call }.to raise_error(Noaa::Unavailable)
    stub_request(:get, /activestations.xml/).to_timeout
    expect { described_class.new(station, client:).call }.to raise_error(Noaa::Unavailable)
  end

  it 'rejects incorrect XML roots and oversized data' do
    stub_request(:get, /activestations.xml/).to_return(body: '<html/>')
    expect { described_class.new(station, client:).call }.to raise_error(Noaa::Unavailable)
    stub_request(:get, /activestations.xml/).to_return(body: 'x' * (2.megabytes + 1))
    expect { described_class.new(station, client:).call }.to raise_error(Noaa::Unavailable)
  end

  it 'validates ranges, units, coordinates and outbound paths' do
    expect { described_class.new(station, hours: '999', client:) }.to raise_error(Noaa::NoData)
    expect { described_class.new(station, units: 'bad', client:) }.to raise_error(Noaa::NoData)
    expect { described_class.new({}, client:).call }.to raise_error(Noaa::NoData)
    expect { client.get('https://example.org/') }.to raise_error(Noaa::NoData)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end
end
