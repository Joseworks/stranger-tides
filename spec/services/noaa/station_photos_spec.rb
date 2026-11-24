# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::StationPhotos do
  let(:station) { { 'station_id' => '9414290' } }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  it 'uses the official photo index and shares its cache across stations' do
    request = stub_request(:get, described_class::INDEX_URL)
              .to_return(body: { '9414290' => 'ABCDFG', '9099064' => 'AC' }.to_json)
    result = described_class.new(station, cache:).call
    expect(result).to include(photo_count: 6,
                              image_url: "#{described_class::PHOTO_ROOT}/9414290A.jpg",
                              gallery_url: 'https://tidesandcurrents.noaa.gov/stationphotos.html?id=9414290')
    expect(described_class.new({ 'station_id' => '9099064' }, cache:).call[:photo_count]).to eq(2)
    expect(request).to have_been_requested.once
  end

  it 'distinguishes a missing photograph from a failed photo feed' do
    stub_request(:get, described_class::INDEX_URL).to_return(body: '{}')
    expect(described_class.new(station, cache:).call).to include(image_url: nil, photo_count: 0)
  end

  it 'does not turn unexpected index values into image URLs' do
    ['../other', 'A.jpg?url=https://example.org', {}, '', nil].each do |value|
      stub_request(:get, described_class::INDEX_URL).to_return(body: { '9414290' => value }.to_json)
      result = described_class.new(station, cache: ActiveSupport::Cache::NullStore.new).call
      expect(result[:image_url]).to be_nil
    end
  end

  ['not json', '[]'].each do |body|
    it "rejects an invalid photo feed: #{body}" do
      stub_request(:get, described_class::INDEX_URL).to_return(body:)
      expect { described_class.new(station, cache:).call }.to raise_error(Noaa::Unavailable)
    end
  end

  it 'does not cache failed requests and recovers on a later attempt' do
    request = stub_request(:get, described_class::INDEX_URL)
    request.to_return(status: 503).then.to_return(body: { '9414290' => 'A' }.to_json)
    photos = described_class.new(station, cache:)
    expect { photos.call }.to raise_error(Noaa::Unavailable)
    expect(photos.call[:photo_count]).to eq(1)
    expect(request).to have_been_requested.twice
  end

  it 'bounds a network timeout without disrupting station data' do
    request = stub_request(:get, described_class::INDEX_URL).to_timeout
    expect { described_class.new(station, cache:).call }.to raise_error(Noaa::Unavailable)
    expect(request).to have_been_requested.once
  end
end
