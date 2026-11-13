# frozen_string_literal: true

# This standalone server never runs inside a deployed application.
ENV['RAILS_ENV'] = 'test'
require 'uri'
url = URI(ENV.fetch('DATABASE_URL'))
abort 'Browser tests require a local database ending in _browser_test' unless
  %w[localhost 127.0.0.1].include?(url.host) && url.path.end_with?('_browser_test')

require_relative '../../config/environment'
require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)

stations = [
  { station_id: '9414290', station_name: 'San Francisco', latitude: '37.8063',
    longitude: '-122.4659' },
  { station_id: '9099064', station_name: 'Duluth', latitude: '46.775', longitude: '-92.092' }
]
if Station.none?
  Station.create!(station_name: 'Browser fixtures', metadata: stations,
                  tide_info: stations.pluck(:station_id))
else
  unless Station.count == 1 && Station.last.station_name == 'Browser fixtures'
    abort 'Browser fixture database contains unexpected data'
  end
end

datum_url = %r{https://api\.tidesandcurrents\.noaa\.gov/mdapi/prod/webapi/stations/\d+/datums\.json}
WebMock.stub_request(:get, datum_url).to_return(
  headers: { 'Content-Type' => 'application/json' },
  body: { datums: [{ name: 'MLLW' }] }.to_json
)
data_url = %r{https://api\.tidesandcurrents\.noaa\.gov/api/prod/datagetter}
WebMock.stub_request(:get, data_url).to_return do |request|
  id = URI.decode_www_form(request.uri.query).to_h.fetch('station')
  station = stations.find { |s| s[:station_id] == id } || raise('Unexpected station')
  {
    headers: { 'Content-Type' => 'application/json' },
    body: {
      metadata: { id: id, name: station[:station_name],
                  lat: station[:latitude], lon: station[:longitude] },
      data: [
        { t: '2026-11-11 00:00', v: '0.12', s: '0.01' },
        { t: '2026-11-11 00:06', v: '0.15', s: '0.01' },
        { t: '2026-11-12 00:00', v: '0.18', s: '0.01' }
      ]
    }.to_json
  }
end

require 'rackup'
Rackup::Server.start(app: Rails.application, Host: '127.0.0.1', Port: 3467, server: 'puma')
