# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Noaa::Client do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:client) { described_class.new(cache:) }
  let(:url) { 'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=waterlevels' }

  it 'caches a successful payload without repeating the HTTP request' do
    request = stub_request(:get, url).to_return(body: { stations: [] }.to_json)
    2.times { client.get('/mdapi/prod/webapi/stations.json', { type: 'waterlevels' }) }
    expect(request).to have_been_requested.once
  end

  it 'retries a transient error once, then returns data' do
    request = stub_request(:get,
                           url).to_return(status: 503).then.to_return(body: { count: 1 }.to_json)
    expect(client.get('/mdapi/prod/webapi/stations.json',
                      { type: 'waterlevels' })).to eq('count' => 1)
    expect(request).to have_been_requested.twice
  end

  [429, 500].each do |status|
    it "bounds retries for HTTP #{status} and never caches a failure" do
      request = stub_request(:get, url).to_return(status:)
      2.times do
        expect do
          client.get('/mdapi/prod/webapi/stations.json', { type: 'waterlevels' })
        end.to raise_error(Noaa::Unavailable)
      end
      expect(request).to have_been_requested.times(4)
    end
  end

  it 'turns timeouts into a bounded, readable failure' do
    request = stub_request(:get, url).to_timeout
    expect do
      client.get('/mdapi/prod/webapi/stations.json', { type: 'waterlevels' })
    end.to raise_error(Noaa::Unavailable)
    expect(request).to have_been_requested.twice
  end

  it 'handles NOAA error objects returned with HTTP 200' do
    stub_request(:get, url).to_return(body: { error: { message: 'No data was found.' } }.to_json)
    expect do
      client.get('/mdapi/prod/webapi/stations.json', { type: 'waterlevels' })
    end.to raise_error(Noaa::NoData)
  end

  ['not json', '[]'].each do |body|
    it "rejects malformed or unexpected payload #{body}" do
      stub_request(:get, url).to_return(body:)
      expect do
        client.get('/mdapi/prod/webapi/stations.json', { type: 'waterlevels' })
      end.to raise_error(Noaa::Unavailable)
    end
  end

  it 'makes no HTTP request when the overall response budget is exhausted' do
    client = described_class.new(cache:,
                                 deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1)
    expect { client.get('/mdapi/prod/webapi/stations.json') }.to raise_error(Noaa::Unavailable)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end
end
