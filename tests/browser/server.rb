# frozen_string_literal: true

# Standalone, offline-only browser server. Never runs in a deployed environment.
ENV['RAILS_ENV'] = 'test'
require 'uri'
url = URI(ENV.fetch('DATABASE_URL'))
abort 'Browser tests require a local database ending in _browser_test' unless
  %w[localhost 127.0.0.1].include?(url.host) && url.path.end_with?('_browser_test')
require_relative '../../config/environment'
require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ENV['STRANGER_TIDES_EMBED_MAPS_API_KEY'] = 'offline-browser-fixture'

stations = [
  { 'station_id' => '9414290', 'station_name' => 'San Francisco', 'latitude' => 37.8063,
    'longitude' => -122.4659, 'state' => 'CA',
    'capabilities' => %w[waterlevels tidepredictions waterlevelsandmet] },
  { 'station_id' => '9099064', 'station_name' => 'Duluth', 'latitude' => 46.775,
    'longitude' => -92.092,
    'state' => 'MN', 'greatlakes' => true, 'capabilities' => ['waterlevels'] },
  { 'station_id' => 'TWC0331', 'station_name' => 'Prediction Harbor', 'latitude' => 38,
    'longitude' => -123, 'state' => 'CA', 'capabilities' => ['tidepredictions'] }
]
if Station.none?
  Station.create!(station_name: Noaa::Catalog::SNAPSHOT_NAME, metadata: {
                    version: 1, retrieved_at: Time.current.iso8601, stations:
                  })
else
  actual = Noaa::Catalog.new.stations
  unless Station.count == 1 && actual == stations
    abort 'Browser fixture database contains unexpected data'
  end
end
WebMock.stub_request(:get, %r{/mdapi/prod/webapi/stations/\d+/datums.json}).to_return do |request|
  { body: { datums: [{ name: request.uri.path.include?('9099064') ? 'GL_LWD' : 'MLLW' }] }.to_json }
end
data_url = %r{https://api\.tidesandcurrents\.noaa\.gov/api/prod/datagetter}
WebMock.stub_request(:get, data_url).to_return do |request|
  params = URI.decode_www_form(request.uri.query).to_h
  station = stations.find do |s|
    s['station_id'] == params['station']
  end || raise('Unexpected station')
  product = params.fetch('product')
  if product == 'water_level' && station['station_id'] == '9099064' && params['datum'] != 'IGLD'
    raise 'Great Lakes chart requires the IGLD datum'
  end

  now = Time.current.utc.change(sec: 0)
  scale = params['units'] == 'metric' ? 0.3048 : 1
  rows = [18, 12, 6].map.with_index do |minutes, index|
    { t: (now - minutes.minutes).strftime('%Y-%m-%d %H:%M'),
      v: index == 1 ? '' : (0.12 + (index * 0.03)) * scale, q: 'p', f: '0,0,0,0', s: '10' }
  end
  if params['interval'] == 'hilo'
    rows = [{ t: (now + 2.hours).strftime('%Y-%m-%d %H:%M'), v: 2 * scale, type: 'H' },
            { t: (now + 8.hours).strftime('%Y-%m-%d %H:%M'), v: 0.1 * scale, type: 'L' }]
  end
  { body: { (product == 'predictions' ? :predictions : :data) => rows }.to_json }
end
require 'rackup'
Rackup::Server.start(app: Rails.application, Host: '127.0.0.1', Port: 3467, server: 'puma')
