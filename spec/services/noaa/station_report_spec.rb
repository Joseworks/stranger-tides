# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::StationReport do
  let(:station) do
    { 'station_id' => '9414290', 'station_name' => 'San Francisco',
      'capabilities' => ['waterlevels'] }
  end
  let(:client) { Noaa::Client.new(cache: ActiveSupport::Cache::NullStore.new) }
  let(:rows) do
    [{ t: '2026-11-13 18:48', v: '0', q: 'v', f: '0,0,0,0' },
     { t: '2026-11-13 18:54', v: '', q: 'p' }]
  end
  let(:base) do
    { 'station' => '9414290', 'units' => 'english', 'time_zone' => 'gmt',
      'application' => 'StrangerTides', 'format' => 'json',
      'begin_date' => '20261111 19:00', 'end_date' => '20261113 19:00' }
  end

  before do
    travel_to(Time.utc(2026, 11, 13, 19))
    stub_request(:get, 'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/9414290/datums.json')
      .to_return(body: { datums: [{ name: 'MLLW' }] }.to_json)
    stub_request(:get, /sensors.json/).to_return(body: { sensors: [] }.to_json)
    stub_request(:get, %r{/stations/[A-Za-z0-9]+\.json})
      .to_return(body: { stations: [{ id: '9414290', timezonecorr: -8,
                                      observedst: true }] }.to_json)
  end

  def water_request(datum: 'MLLW', body: { data: rows })
    stub_request(:get, 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter')
      .with(query: base.merge('product' => 'water_level',
                              'datum' => datum)).to_return(body: body.to_json)
  end

  def weather_requests
    stub_request(:get, /sensors.json/).to_return(body: { sensors: [
      { name: 'Wind', status: 1 }, { name: 'Barometric Pressure', status: 1 },
      { name: 'Relative Humidity', status: 1 },
      { name: 'Water Temperature', status: 0, message: '2026-11-13&Under review' }
    ] }.to_json)
    %w[wind air_pressure humidity].each do |product|
      stub_request(:get, /datagetter/)
        .with(query: base.merge('product' => product))
        .to_return(body: { data: [{ t: '2026-11-13 18:54', v: '64', s: '12',
                                    d: '180', g: '15' }] }.to_json)
    end
  end

  it 'fetches each payload once and preserves real zero, null gaps, timestamps, and quality' do
    request = water_request
    result = described_class.new(station, client:).call
    expect(result[:observations].pluck(:value)).to eq([0.0, nil])
    expect(result[:observations].first).to include(
      timestamp: Time.utc(2026, 11, 13, 18, 48).to_i * 1000, quality: 'v', flags: '0,0,0,0'
    )
    expect(result[:latest][:value]).to eq(0.0)
    expect(result).to include(stale: false, station_timezone: 'America/Los_Angeles')
    expect(request).to have_been_requested.once
    expect(WebMock).to have_requested(:get, /datums.json/).once
  end

  it 'uses IGLD for published Great Lakes datums' do
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: 'GL_LWD' }] }.to_json)
    water_request(datum: 'IGLD')
    expect(described_class.new(station.merge('greatlakes' => true),
                               client:).call[:datum]).to eq('IGLD')
  end

  it 'refuses to invent a height reference if NOAA has no supported datum' do
    stub_request(:get, /datums.json/).to_return(body: { datums: [] }.to_json)
    expect do
      described_class.new(station, client:).call
    end.to raise_error(Noaa::NoData, /height reference/)
    expect(WebMock).not_to have_requested(:get, /datagetter/)
  end

  it 'returns an explicit empty state for NOAA error objects' do
    water_request(body: { error: { message: 'No data' } })
    result = described_class.new(station, client:).call
    expect(result).to include(observations: [], latest: nil, stale: true)
    expect(result[:warnings].first[:product]).to eq('water_level')
  end

  it 'keeps observations usable when prediction requests fail' do
    water_request
    stub_request(:get,
                 /datagetter/)
      .with(query: hash_including('product' => 'predictions')).to_return(status: 503)
    result = described_class.new(station.merge('capabilities' => %w[waterlevels tidepredictions]),
                                 client:).call
    expect(result[:latest][:value]).to eq(0.0)
    expect(result[:predictions]).to eq([])
    expect(result[:warnings].pluck(:product)).to include('predictions')
  end

  it 'raises an upstream error when no data request succeeds' do
    stub_request(:get, /datagetter/).to_return(status: 503)
    expect do
      described_class.new(station.merge('capabilities' => %w[waterlevels tidepredictions]),
                          client:).call
    end.to raise_error(Noaa::Unavailable, /temporarily unavailable/)
  end

  it 'keeps a legitimate empty response distinct from transport failure' do
    water_request(body: { data: [] })
    result = described_class.new(station, client:).call
    expect(result).to include(observations: [], latest: nil, weather: {}, warnings: [])
  end

  it 'requests high/low intervals for subordinate locations without requesting observations' do
    station = { 'station_id' => 'TWC0331', 'station_name' => 'Prediction location',
                'capabilities' => ['tidepredictions'], 'prediction_type' => 'S' }
    past = base.merge('station' => 'TWC0331', 'product' => 'predictions', 'datum' => 'MLLW',
                      'interval' => 'hilo')
    future = past.merge('begin_date' => '20261113 19:00', 'end_date' => '20261114 19:00')
    stub_request(:get, /datagetter/)
      .with(query: past)
      .to_return(body: { predictions: [{ t: '2026-11-13 18:00', v: '1.2' }] }.to_json)
    stub_request(:get, /datagetter/)
      .with(query: future)
      .to_return(body: { predictions: [{ t: '2026-11-13 21:00', v: '2.1', type: 'H' }] }.to_json)
    result = described_class.new(station, client:).call
    expect(result[:observations]).to eq([])
    expect(result[:predictions].first[:value]).to eq(1.2)
    expect(result[:events].first[:type]).to eq('H')
    expect(WebMock).not_to have_requested(:get, /datums.json/)
  end

  it 'displays enabled measurements including pressure and humidity and handles wind field s' do
    station = station().merge('capabilities' => ['waterlevelsandmet'])
    weather_requests
    result = described_class.new(station, client:).call
    expect(result[:weather]['wind']).to include(value: 12.0, direction: '180', gust: '15')
    expect(result[:weather].keys).to contain_exactly('wind', 'air_pressure', 'humidity')
    expect(result[:sensors].last).to include(enabled: false, message: 'Under review')
    expect(WebMock).not_to have_requested(:get, /datagetter/)
      .with(query: hash_including('product' => 'water_temperature'))
  end

  it 'preserves observations when sensor metadata is unavailable' do
    water_request
    stub_request(:get, /sensors.json/).to_return(status: 503)
    result = described_class.new(station.merge('capabilities' => %w[waterlevels waterlevelsandmet]),
                                 client:).call
    expect(result[:latest][:value]).to eq(0.0)
    expect(result[:weather]).to eq({})
    expect(result[:warnings].pluck(:product)).to include('weather')
  end

  it 'returns full enabled sensor histories even without a catalog weather flag' do
    water_request
    weather_requests
    request = stub_request(:get, /datagetter/)
              .with(query: base.merge('product' => 'wind'))
              .to_return(body: { data: [
                { t: '2026-11-13 18:42', s: '0', g: '0' },
                { t: '2026-11-13 18:48', s: '' },
                { t: '2026-11-13 18:54', s: '12', g: '15' }
              ] }.to_json)

    result = described_class.new(station, client:).call
    expect(result[:weather_series]['wind'].pluck(:value)).to eq([0.0, nil, 12.0])
    expect(result[:weather]['wind']).to include(value: 12.0, gust: '15')
    expect(result[:weather_series].keys).to contain_exactly('wind', 'air_pressure', 'humidity')
    expect(result[:observations].first[:value]).to eq(0.0)
    expect(request).to have_been_requested.once
  end

  it 'drops invalid timestamps and nonfinite numbers, sorts and deduplicates measurements' do
    water_request(body: { data: [nil, { t: 'bad', v: '9' }, rows.last, rows.first, rows.first,
                                 { t: '2026-11-13 18:42', v: 'Infinity' }] })
    result = described_class.new(station, client:).call
    expect(result[:observations].pluck(:value)).to eq([nil, 0.0, nil])
  end

  it 'flags old readings even when the HTTP request itself succeeds' do
    water_request(body: { data: [{ t: '2026-11-12 18:00', v: '1' }] })
    expect(described_class.new(station, client:).call[:stale]).to be(true)
  end

  it 'enforces unit and range limits without calling NOAA' do
    expect { described_class.new(station, hours: '1000', client:) }.to raise_error(Noaa::NoData)
    expect { described_class.new(station, units: 'bad', client:) }.to raise_error(Noaa::NoData)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'requests bounded 30-day histories and future plans independently' do
    stub_request(:get, /datagetter/).to_return do |request|
      params = URI.decode_www_form(request.uri.query).to_h
      { body: { (params['product'] == 'predictions' ? :predictions : :data) => rows }.to_json }
    end
    result = described_class.new(station.merge('capabilities' => %w[waterlevels tidepredictions]),
                                 hours: 720, future_hours: 720, client:).call
    expect(result).to include(hours: 720, future_hours: 720)
    expect(WebMock).to have_requested(:get, /datagetter/).with(query: hash_including(
      'product' => 'water_level', 'begin_date' => '20261014 19:00', 'end_date' => '20261113 19:00'
    )).once
    expect(WebMock).to have_requested(:get, /datagetter/).with(query: hash_including(
      'product' => 'predictions', 'begin_date' => '20261113 19:00', 'end_date' => '20261213 19:00'
    )).twice
  end

  it 'rejects unsupported planning periods without making requests' do
    expect { described_class.new(station, future_hours: -1, client:) }.to raise_error(Noaa::NoData)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  def extra_sensor_requests
    stub_request(:get, /sensors.json/).to_return(body: { sensors: [
      { name: 'Conductivity', status: 1 }, { name: 'Visibility', status: 1 },
      { name: 'AIR GAP', status: 1 }
    ] }.to_json)
    stub_request(:get, /datagetter/).with(query: hash_including('product' => 'salinity'))
                                    .to_return(body: { data: [{ t: '2026-11-13 18:54', s: '32',
                                                                g: '1.02' }] }.to_json)
    %w[conductivity visibility air_gap].each do |product|
      stub_request(:get, /datagetter/).with(query: hash_including('product' => product))
                                      .to_return(body: { data: rows }.to_json)
    end
  end

  it 'graphs extra physical products and specific gravity with the original observations intact' do
    water_request
    extra_sensor_requests
    result = described_class.new(station, client:).call
    expect(result[:weather_series]['salinity'].last[:value]).to eq(32)
    expect(result[:weather_series]['specific_gravity'].last[:value]).to eq(1.02)
    expect(result[:weather_series].keys).to contain_exactly(
      'conductivity', 'visibility', 'air_gap', 'salinity', 'specific_gravity'
    )
    expect(result[:latest][:value]).to eq(0)
  end
end
