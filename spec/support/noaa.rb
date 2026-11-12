# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    stub_request(:get, %r{https://api\.tidesandcurrents\.noaa\.gov/mdapi/prod/webapi/stations/\d+/datums\.json})
      .to_return(headers: { 'Content-Type' => 'application/json' },
                 body: { datums: [{ name: 'MLLW' }] }.to_json)

    stub_request(:get, %r{https://api\.tidesandcurrents\.noaa\.gov/api/prod/datagetter})
      .to_return do |request|
      station_id = CGI.parse(request.uri.query).fetch('station').first
      name, latitude, longitude = {
        '9461710' => ['Atka', '52.2319', '-174.1725'],
        '9461380' => ['Adak Island', '51.8606', '-176.6376']
      }.fetch(station_id, ['Kawaihae', '20.0366', '-155.8294'])
      {
        headers: { 'Content-Type' => 'application/json' },
        body: {
          metadata: { id: station_id, name: name, lat: latitude, lon: longitude },
          data: [
            { t: '2026-11-11 00:00', v: '0.12', s: '0.01' },
            { t: '2026-11-11 00:06', v: '0.15', s: '0.01' },
            { t: '2026-11-12 00:00', v: '0.18', s: '0.01' }
          ]
        }.to_json
      }
    end
  end
end
