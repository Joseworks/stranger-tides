# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::Catalog do
  let(:client) { Noaa::Client.new(cache: ActiveSupport::Cache::NullStore.new) }
  let(:catalog) { described_class.new(client:) }
  let(:one) do
    { id: '9414290', name: 'San Francisco', lat: 37.8, lng: -122.4, tidal: true, state: 'CA' }
  end
  let(:two) { { id: 'TWC0331', name: 'Prediction location', lat: 38, lng: -123 } }

  def response_for(type, rows, count: rows.length)
    stub_request(:get, 'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json')
      .with(query: { type: }).to_return(body: { count:, stations: rows }.to_json)
  end

  before do
    response_for('waterlevels', [one])
    response_for('tidepredictions', [one, two])
    response_for('waterlevelsandmet', [one])
  end

  it 'dry-runs discovery without modifying the database' do
    expect { expect(catalog.refresh[:count]).to eq(2) }.not_to change(Station, :count)
  end

  it 'merges capabilities, keeps string IDs, and publishes an immutable snapshot' do
    catalog.refresh(apply: true)
    expect(catalog.stations.pluck('station_id')).to contain_exactly('9414290', 'TWC0331')
    expect(catalog.find('9414290')['capabilities']).to match_array(described_class::TYPES)
    previous = catalog.snapshot
    original = previous.metadata.deep_dup
    catalog.refresh(apply: true)
    expect(previous.reload.metadata).to eq(original)
    expect(catalog.snapshot.metadata['stations']).to eq(original['stations'])
    expect(Station.count).to eq(2)
  end

  it 'does not replace the last good catalog after an incomplete response' do
    catalog.refresh(apply: true)
    response_for('waterlevels', [one], count: 10)
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::InvalidCatalog)
    expect(Station.count).to eq(1)
    expect(catalog.find('9414290')['station_name']).to eq('San Francisco')
  end

  it 'rejects duplicate IDs rather than silently dropping records' do
    response_for('waterlevels', [one, one])
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::InvalidCatalog, /Duplicate/)
    expect(Station.count).to eq(0)
  end

  it 'rejects malformed coordinates and non-object entries' do
    response_for('waterlevels', [one.merge(lat: 'unknown')])
    expect { catalog.refresh }.to raise_error(Noaa::InvalidCatalog)
    response_for('waterlevels', [nil])
    expect { catalog.refresh }.to raise_error(Noaa::InvalidCatalog)
  end

  it 'preserves existing data when NOAA fails' do
    catalog.refresh(apply: true)
    stub_request(:get, /stations.json/).to_timeout
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::Unavailable)
    expect(Station.count).to eq(1)
  end

  it 'requires explicit review before removing an old station' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9999999',
                                 station_name: 'Old station' }])
    expect(catalog.refresh[:removed]).to eq(['9999999'])
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::InvalidCatalog, /ALLOW_REMOVALS/)
    expect { catalog.refresh(apply: true, allow_removals: true) }.to change(Station, :count).by(1)
  end

  it 'rejects a large per-product loss even when other products grow' do
    old = Array.new(20) { |i| { station_id: (9_000_000 + i).to_s, station_name: 'Old' } }
    Station.create!(station_name: 'All stations', metadata: old)
    expect do
      catalog.refresh(apply: true, allow_removals: true)
    end.to raise_error(Noaa::InvalidCatalog, /shrank/)
  end

  it 'refuses an overlapping publisher instead of writing conflicting snapshots' do
    connection = Station.connection
    allow(connection).to receive(:select_value).and_call_original
    allow(connection).to receive(:select_value)
      .with('SELECT pg_try_advisory_xact_lock(60804221)').and_return(false)
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::InvalidCatalog, /Another/)
    expect(Station.count).to eq(0)
  end

  it 'prevents a slow older fetch from overwriting a newer snapshot' do
    catalog.refresh(apply: true)
    record = catalog.snapshot
    record.update!(metadata: record.metadata.merge('retrieved_at' => 1.hour.from_now.iso8601(6)))
    expect { catalog.refresh(apply: true) }.to raise_error(Noaa::InvalidCatalog, /newer catalog/)
    expect(Station.count).to eq(1)
  end
end
