# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvironmentAgency::Catalog do
  let(:origin) { EnvironmentAgency::Client::ORIGIN + EnvironmentAgency::Client::ROOT }
  let(:row) do
    { stationReference: 'E70039', label: 'Lowestoft', lat: 52.47, long: 1.75,
      status: 'https://environment.data.gov.uk/flood-monitoring/def/core/statusActive',
      measures: [{ parameter: 'level', qualifier: 'Tidal Level', period: 900, unitName: 'mAOD' }] }
  end
  let(:client) { EnvironmentAgency::Client.new(cache: ActiveSupport::Cache::NullStore.new) }
  let(:catalog) { described_class.new(client:) }

  before do
    stub_request(:get, "#{origin}/id/stations").with(query: { type: 'TideGauge', _limit: 1000 })
                                               .to_return(body: { items: [row] }.to_json)
  end

  it 'uses distinct provider IDs and the published national reference' do
    expect(catalog.find('ea-E70039')).to include('provider' => 'environment_agency',
                                                 'datum' => 'ODN', 'source_id' => 'E70039',
                                                 'station_timezone' => 'Europe/London')
    expect { catalog.find('E70039') }.to raise_error(Noaa::NoData)
  end

  it 'rejects unknown or malicious IDs before constructing any reading URL' do
    ['ea-../private', 'https://evil.example', 'ea-X999'].each do |id|
      expect { catalog.find(id) }.to raise_error(Noaa::NoData)
    end
    expect(WebMock).not_to have_requested(:get, /readings|evil/)
  end

  it 'excludes inactive, invalid-coordinate and unsupported-measure stations' do
    rows = [row.merge(status: 'statusClosed'), row.merge(lat: nil),
            row.merge(long: 181), row.merge(measures: []), row]
    stub_request(:get, "#{origin}/id/stations").with(query: hash_including('type' => 'TideGauge'))
                                               .to_return(body: { items: rows }.to_json)
    expect(catalog.stations.pluck('station_id')).to eq(['ea-E70039'])
  end

  it 'retains gauges with missing status and prefers a national-datum pair' do
    local = row.merge(stationReference: 'E70024', status: nil, lat: 52.471,
                      measures: [{ parameter: 'level', qualifier: 'Tidal Level',
                                   period: 900, unitName: 'm' }])
    stub_request(:get, "#{origin}/id/stations")
      .with(query: hash_including('type' => 'TideGauge'))
      .to_return(body: { items: [local, row.merge(status: nil)] }.to_json)
    expect(catalog.stations.length).to eq(1)
    expect(catalog.stations.first).to include('datum' => 'ODN', 'source_status' => 'not supplied')
  end

  it 'converts readings to feet, retains zero/negative values and leaves missing data as gaps' do
    travel_to Time.utc(2026, 11, 25, 12) do
      rows = [{ dateTime: '2026-11-25T11:00:00Z', value: -0.3048 },
              { dateTime: '2026-11-25T11:15:00Z', value: 0 },
              { dateTime: '2026-11-25T11:30:00Z', value: nil },
              { dateTime: 'invalid', value: 3 }, { dateTime: '2026-11-26T00:00:00Z', value: 9 }]
      stub_request(:get,
                   "#{origin}/id/stations/E70039/readings")
        .with(query: hash_including('unitName' => 'mAOD'))
        .to_return(body: { items: rows }.to_json)
      report = EnvironmentAgency::StationReport.new(catalog.find('ea-E70039'), client:).call
      expect(report[:observations].pluck(:value)).to eq([-1.0, 0.0, nil])
      expect(report).to include(interval_minutes: 15, station_timezone: 'Europe/London',
                                datum: 'ODN', future_predictions: [], weather: {})
      expect(report[:latest][:quality]).to be_nil
    end
  end

  it 'bounds history and rejects NOAA-only resolutions without a readings request' do
    station = catalog.find('ea-E70039')
    %w[2020-01-01 bad].each do |first|
      expect do
        EnvironmentAgency::HistoryReport.new(station, begin_date: first,
                                                      end_date: Time.current.utc.to_date.iso8601)
      end.to raise_error(Noaa::NoData)
    end
    expect(WebMock).not_to have_requested(:get, /readings/)
  end

  it 'reports transport and malformed responses without caching failures' do
    ['[]', '{bad', '{"items":null}'].each do |body|
      stub_request(:get, "#{origin}/id/stations").with(query: hash_including('type' => 'TideGauge'))
                                                 .to_return(body:)
      expect { described_class.new(client:).stations }.to raise_error(Noaa::Unavailable)
    end
  end
end
