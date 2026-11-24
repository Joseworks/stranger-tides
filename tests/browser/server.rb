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
    'prediction_type' => 'H', 'capabilities' => %w[waterlevels tidepredictions waterlevelsandmet] },
  { 'station_id' => '9099064', 'station_name' => 'Duluth', 'latitude' => 46.775,
    'longitude' => -92.092,
    'state' => 'MN', 'greatlakes' => true, 'capabilities' => ['waterlevels'] },
  { 'station_id' => 'TWC0331', 'station_name' => 'Prediction Harbor', 'latitude' => 38,
    'longitude' => -123, 'state' => 'CA', 'prediction_type' => 'S',
    'capabilities' => ['tidepredictions'] }
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
WebMock.stub_request(:get, Noaa::Client::ORIGIN + Noaa::Catalog::PATH)
       .with(query: { type: 'waterlevelsandmet', expand: 'sensors' }).to_return(
         body: { count: 2, stations: stations.first(2).map do |s|
           { id: s['station_id'], forecast: s['station_id'] == '9414290',
             outlook: s['station_id'] == '9414290',
             sensors: { sensors: if s['station_id'] == '9414290'
                                   [{ name: 'Conductivity', status: 1 },
                                    { name: 'Visibility', status: 1 }]
                                 else
                                   []
                                 end } }
         end }.to_json
       )
WebMock.stub_request(:get, Noaa::Client::ORIGIN + Noaa::Catalog::PATH)
       .with(query: { type: '1minute' }).to_return(body: {
         count: 1, stations: [{ id: '9414290' }]
       }.to_json)
WebMock.stub_request(:get, %r{/stations/[A-Za-z0-9]+/products.json}).to_return(body: {
  products: [{ name: 'Station datums',
               value: 'https://tidesandcurrents.noaa.gov/datums.html?id=9414290' }]
}.to_json)
WebMock.stub_request(:get, %r{/dpapi/prod/webapi/htb.json}).to_return do
  row = { date: Time.current.utc.to_date.iso8601, likelihood: 12.5,
          threshold: 7, updated: Time.current.utc.to_date.iso8601 }
  { body: { floodLikelihood: [{ 'NOS minor' => [row] }] }.to_json }
end
WebMock.stub_request(:get, 'https://www.ndbc.noaa.gov/activestations.xml').to_return(body:
  '<stations count="1"><station id="46026" name="Offshore test buoy" ' \
  'lat="37.8" lon="-122.7" met="y" type="buoy" /></stations>')
WebMock.stub_request(:get, 'https://www.ndbc.noaa.gov/data/realtime2/46026.txt').to_return do
  now = Time.current.utc
  header = "#YY MM DD hh mm WDIR WSPD GST WVHT DPD APD MWD PRES ATMP WTMP\n# units\n"
  rows = [60, 30].map do |minutes|
    "#{(now - minutes.minutes).strftime('%Y %m %d %H %M')} 270 5 8 2.5 12 9 300 1013 16 14"
  end
  { body: header + rows.join("\n") }
end
def observation_fixture(station, now, scale)
  base = station['station_id'] == '9099064' ? 602.12 : 0.12
  [18, 12, 6].map.with_index do |minutes, index|
    { t: (now - minutes.minutes).strftime('%Y-%m-%d %H:%M'),
      v: index == 1 ? '' : (base + (index * 0.03)) * scale, q: 'p', f: '0,0,0,0',
      s: index == 1 ? '' : '10', g: index == 1 ? '' : '14', d: index == 1 ? '' : '180' }
  end
end

def fixture_time(params, key)
  value = params.fetch(key)
  value += ' 00:00' if value.length == 8
  Time.strptime("#{value} +0000", '%Y%m%d %H:%M %z')
end

def future_fixture?(params, now)
  params['product'] == 'predictions' && fixture_time(params, 'end_date') > now
end

def forecast_fixture(now, scale)
  [1, 2, 3].map { |h| { t: (now + h.hours).strftime('%Y-%m-%d %H:%M'), v: 2 * scale } }
end

def fixture_rows(params, station)
  product = params.fetch('product')
  if product == 'monthly_mean'
    return [{ year: '2020', month: '1', MSL: '0', inferred: '0' },
            { year: '2020', month: '2', MSL: '', inferred: '1' },
            { year: '2020', month: '3', MSL: '3.25', inferred: '0' }]
  end
  future = product == 'ofs_water_level' || future_fixture?(params, Time.current.utc.change(sec: 0))
  now = fixture_time(params, future ? 'begin_date' : 'end_date')
  scale = params['units'] == 'metric' ? 0.3048 : 1
  rows = if future
           forecast_fixture(now, scale)
         else
           observation_fixture(station, now, scale)
         end
  rows = forecast_fixture(now, scale) if product == 'ofs_water_level'
  if params['interval'] == 'hilo'
    rows = [{ t: (now + 2.hours).strftime('%Y-%m-%d %H:%M'), v: 2 * scale, type: 'H' },
            { t: (now + 8.hours).strftime('%Y-%m-%d %H:%M'), v: 0.1 * scale, type: 'L' }]
  end
  rows
end

station_metadata_url = %r{/mdapi/prod/webapi/stations/[A-Za-z0-9]+\.json}
WebMock.stub_request(:get, station_metadata_url).to_return do |request|
  id = request.uri.path.split('/').last.delete_suffix('.json')
  offset = id == '9099064' ? -6 : -8
  { body: { stations: [{ id:, timezonecorr: offset, observedst: true }] }.to_json }
end
WebMock.stub_request(:get, %r{/mdapi/prod/webapi/stations/\d+/datums.json}).to_return do |request|
  { body: { datums: [{ name: request.uri.path.include?('9099064') ? 'GL_LWD' : 'MLLW' }] }.to_json }
end
WebMock.stub_request(:get, %r{/mdapi/prod/webapi/stations/\d+/sensors.json}).to_return(
  body: { sensors: [{ name: 'Wind', status: 1 }, { name: 'Air Temperature', status: 1 },
                    { name: 'Barometric Pressure', status: 1 },
                    { name: 'Relative Humidity', status: 1 },
                    { name: 'Water Temperature', status: 0,
                      message: '2026-11-13&Under review' }] }.to_json
)
data_url = %r{https://api\.tidesandcurrents\.noaa\.gov/api/prod/datagetter}
WebMock.stub_request(:get, data_url).to_return do |request|
  params = URI.decode_www_form(request.uri.query).to_h
  station = stations.find do |s|
    s['station_id'] == params['station']
  end || raise('Unexpected station')
  product = params.fetch('product')
  raise 'Disabled water sensor must not be requested' if product == 'water_temperature'
  raise 'Subordinate predictions require high/low events' if
    station['prediction_type'] == 'S' && params['interval'] != 'hilo'
  if product == 'water_level' && station['station_id'] == '9099064' && params['datum'] != 'IGLD'
    raise 'Great Lakes chart requires the IGLD datum'
  end

  rows = fixture_rows(params, station)
  { body: { (product == 'predictions' ? :predictions : :data) => rows }.to_json }
end
require 'rackup'
Rackup::Server.start(app: Rails.application, Host: '127.0.0.1', Port: 3467, server: 'puma')
