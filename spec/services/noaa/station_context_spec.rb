# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::StationContext do
  let(:station) do
    { 'station_id' => '9414290', 'station_name' => 'San Francisco',
      'latitude' => 37.8, 'longitude' => -122.5,
      'capabilities' => %w[waterlevels tidepredictions] }
  end
  let(:client) { Noaa::Client.new(cache: ActiveSupport::Cache::NullStore.new) }
  let(:metadata) do
    { id: '9414290', forecast: true, outlook: true,
      sensors: { sensors: [{ name: 'Conductivity', status: 1 },
                           { name: 'Visibility', status: 1 }, { name: 'AIR GAP', status: 0 }] } }
  end
  let(:datum) { 'MLLW' }

  before do
    travel_to(Time.utc(2026, 11, 14, 19))
    stub_request(:get, /stations.json/)
      .with(query: { type: 'waterlevelsandmet', expand: 'sensors' })
      .to_return(body: { count: 1, stations: [metadata] }.to_json)
    stub_request(:get, /stations.json/).with(query: { type: '1minute' })
                                       .to_return(body: { count: 1,
                                                          stations: [{ id: '9414290' }] }.to_json)
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: datum }] }.to_json)
    stub_request(:get, /products.json/).to_return(body: { products: [
      { name: 'Datums', value: 'http://tidesandcurrents.noaa.gov/datums.html?id=9414290' },
      { name: 'Unsafe', value: 'javascript:alert(1)' },
      { name: 'Foreign', value: 'https://example.org/' },
      { name: 'Credentials', value: 'https://user@tidesandcurrents.noaa.gov/' },
      nil, { name: 'Bad', value: 'http://[' }
    ] }.to_json)
    stub_request(:get, /datagetter/).to_return(body: { data: [
      { t: 'bad' }, nil, { t: '2026-11-14 18:00', v: '1' },
      { t: '2026-11-14 20:00', v: '2' }, { t: '2026-11-14 20:00', v: '2' },
      { t: '2026-11-16 20:00', v: '3' }, { t: '2026-11-14 21:00', v: 'NaN' }
    ] }.to_json)
    stub_request(:get, /htb.json/).to_return(body: { floodLikelihood: [nil, { 'NOS minor' => [
      nil, { date: 'bad' }, { date: nil }, { date: 123 },
      { date: '2026-11-14', likelihood: 20, threshold: 5, updated: '2026-11-01' },
      { date: '2026-11-14', likelihood: 20, threshold: 5 },
      { date: '2026-11-15', likelihood: 101, threshold: 5 },
      { date: '2026-11-16', likelihood: 0, threshold: 'NaN' },
      { date: '2026-11-13', likelihood: 0, threshold: 5 }
    ] }] }.to_json)
  end

  it 'discovers advertised extras without mutating the saved catalog or inferring disabled products' do
    result = Noaa::ProductCatalog.new(client:).enrich([station]).first
    expect(result['additional_products']).to contain_exactly(
      'conductivity', 'salinity', 'specific_gravity', 'visibility',
      'ofs_water_level', 'flood_outlook', 'one_minute_water_level'
    )
    expect(result['products_checked']).to be(true)
    expect(station).not_to have_key('additional_products')
  end

  it 'preserves station discovery when product discovery fails and marks it unknown' do
    stub_request(:get, /stations.json/).to_return(status: 503)
    catalog = Noaa::ProductCatalog.new(client:)
    expect(catalog.enrich([station]).first).to include('station_id' => '9414290',
                                                       'products_checked' => false)
    expect(catalog.warning).to include('temporarily unavailable')
  end

  it 'rejects incomplete discovery and still accepts catalogs without a matching station' do
    stub_request(:get, /stations.json/).to_return(body: { count: 2, stations: [metadata] }.to_json)
    result = Noaa::ProductCatalog.new(client:).enrich([station]).first
    expect(result['products_checked']).to be(false)
    stub_request(:get, /stations.json/).to_return(body: { count: 0, stations: [] }.to_json)
    result = Noaa::ProductCatalog.new(client:).enrich([station]).first
    expect(result['additional_products']).to eq([])
  end

  it 'preserves other capabilities when only one-minute discovery fails' do
    stub_request(:get, /stations.json/).with(query: { type: '1minute' })
                                       .to_return(body: { count: 1, stations: [] }.to_json)
    result = Noaa::ProductCatalog.new(client:).enrich([station]).first
    expect(result['additional_products']).to include('ofs_water_level')
    expect(result['additional_products']).not_to include('one_minute_water_level')
  end

  it 'returns bounded model guidance, explicit-datum outlooks and safe NOAA product links' do
    result = described_class.new(station, client:).call
    expect(result[:forecast].pluck(:value)).to eq([2.0, nil])
    expect(result[:flood_outlook]).to eq([{ date: '2026-11-14', likelihood: 20.0,
                                            threshold: 5.0, updated: '2026-11-01' }])
    expect(result[:products].sole).to include(name: 'Datums')
    expect(result[:products].sole[:url]).to start_with('https://tidesandcurrents.noaa.gov/')
    expect(result[:one_minute]).not_to be_empty
    expect(WebMock).to have_requested(:get, /htb.json/)
      .with(query: hash_including('datum' => 'MLLW', 'units' => 'english')).once
  end

  it 'isolates optional failures without losing successful forecast data' do
    stub_request(:get, /htb.json/).to_return(status: 503)
    result = described_class.new(station, client:).call
    expect(result[:forecast]).not_to be_empty
    expect(result[:flood_outlook]).to eq([])
    expect(result[:warnings].join).to include('Flood outlook')
  end

  context 'with Great Lakes metadata' do
    let(:datum) { 'IGLD' }

    it 'uses the same IGLD reference for model forecasts and omits coastal tide-flood outlooks' do
      result = described_class.new(station, units: 'metric', client:).call
      expect(result).to include(datum: 'IGLD', units: 'metric', flood_outlook: [])
      expect(WebMock).not_to have_requested(:get, /htb.json/)
      expect(WebMock).to have_requested(:get, /datagetter/)
        .with(query: hash_including('product' => 'ofs_water_level', 'datum' => 'IGLD',
                                    'units' => 'metric')).once
    end
  end

  it 'does not invent support for products that are not advertised' do
    metadata[:forecast] = false
    metadata[:outlook] = false
    stub_request(:get, /stations.json/)
      .with(query: { type: 'waterlevelsandmet', expand: 'sensors' })
      .to_return(body: { count: 1, stations: [metadata] }.to_json)
    stub_request(:get, /stations.json/).with(query: { type: '1minute' })
                                       .to_return(body: { count: 0, stations: [] }.to_json)
    result = described_class.new(station, client:).call
    expect(result).to include(forecast: [], flood_outlook: [], one_minute: [])
    expect(WebMock).not_to have_requested(:get, /datagetter/)
  end

  it 'keeps independently confirmed one-minute products without a met catalog row' do
    stub_request(:get, /stations.json/)
      .with(query: { type: 'waterlevelsandmet', expand: 'sensors' })
      .to_return(body: { count: 0, stations: [] }.to_json)
    enriched = Noaa::ProductCatalog.new(client:).enrich([station]).first
    expect(enriched).to include('additional_products' => ['one_minute_water_level'],
                                'products_checked' => false)
    expect(described_class.new(station, client:).call[:one_minute]).not_to be_empty
  end

  it 'preserves independent one-minute data when the met collection fails' do
    stub_request(:get, /stations.json/)
      .with(query: { type: 'waterlevelsandmet', expand: 'sensors' }).to_return(status: 503)
    result = described_class.new(station, client:).call
    expect(result[:one_minute]).not_to be_empty
    expect(result[:forecast]).to be_empty
    expect(result[:warnings].join).to include('temporarily unavailable')
  end

  [503, 200].each do |status|
    it "preserves independent product links when height references fail (#{status})" do
      stub_request(:get, /datums.json/).to_return(status:, body: { datums: [] }.to_json)
      result = described_class.new(station, client:).call
      expect(result).to include(datum: nil, one_minute: [], forecast: [], flood_outlook: [])
      expect(result[:products].sole[:name]).to eq('Datums')
      expect(result[:warnings].join).to include('Height reference')
      expect(WebMock).not_to have_requested(:get, /datagetter|htb.json/)
    end
  end

  it 'validates units before any requests' do
    expect { described_class.new(station, units: 'bad', client:) }.to raise_error(Noaa::NoData)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end
end
