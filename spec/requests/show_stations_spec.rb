# frozen_string_literal: true

require 'rails_helper'
# Request coverage spans the HTML explorer and its JSON API.
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Station explorer' do
  before do
    stub_request(:get, Noaa::Client::ORIGIN + Noaa::Catalog::PATH)
      .with(query: { type: 'waterlevelsandmet', expand: 'sensors' })
      .to_return(body: { count: 0, stations: [] }.to_json)
    stub_request(:get, Noaa::Client::ORIGIN + Noaa::Catalog::PATH)
      .with(query: { type: '1minute' }).to_return(body: { count: 0, stations: [] }.to_json)
  end

  it 'renders a searchable, keyboard-accessible explorer and fingerprinted marker icon' do
    get '/'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('station-search', 'station-results', 'Close station details')
    expect(response.body).to match(/data-marker-icon="[^" ]*orange_marker[^" ]*\.png"/)
  end

  it 'returns a clear refresh instruction to old browser tabs' do
    post '/show_graph', params: { content: '1617433' }, xhr: true
    expect(response).to have_http_status(:gone)
    expect(response.parsed_body['error']).to include('reload')
  end

  it 'publishes consistent browser identity metadata and a local favicon' do
    get '/'
    page = response.parsed_body
    names = %w[application-name apple-mobile-web-app-title].map do |name|
      page.at_css("meta[name='#{name}']")['content']
    end
    expect(names).to eq(['Stranger Tides', 'Stranger Tides'])
    expect(page.at_css('html')['lang']).to eq('en')
    expect(page.at_css('meta[charset]')['charset']).to eq('utf-8')
    expect(page.at_css('link[rel~="icon"]')['href'])
      .to match(%r{\A/[^/]+/favicon_jw-[a-f0-9]+\.ico\z})
  end

  it 'limits location requests to this origin without pregranting browser consent' do
    ['/', '/stations.json'].each do |path|
      get path
      expect(response.headers['Permissions-Policy']).to eq('geolocation=(self)')
      expect(response.headers['Feature-Policy']).to eq("geolocation 'self'")
    end
  end

  it 'returns an empty catalog without raising when no snapshot exists' do
    get '/stations.json'
    expect(response.parsed_body).to include('stations' => [],
                                            'status' => {
                                              'refreshed_at' => nil, 'stale' => true
                                            })
  end

  it 'reads the named inventory rather than whichever row was inserted last' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290',
                                 station_name: 'San Francisco' }])
    Station.create!(station_name: 'Unrelated', metadata: [])
    get '/stations.json'
    expect(response.parsed_body['stations'].pluck('station_id')).to eq(['9414290'])
  end

  it 'rejects station IDs outside the catalog without calling NOAA' do
    get '/stations/9999999/report'
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to include('current catalog')
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'rejects unsupported hours before requesting NOAA' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290',
                                 station_name: 'San Francisco' }])
    get '/stations/9414290/report', params: { hours: '999999' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'validates every additional endpoint before contacting NOAA' do
    %w[context nearby].each do |endpoint|
      get "/stations/9999999/#{endpoint}"
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'rejects invalid product options before contacting NOAA' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290', station_name: 'San Francisco' }])
    [['context', { units: 'bad' }], ['nearby', { hours: 999 }],
     ['report', { future_hours: 999 }]].each do |endpoint, options|
      get "/stations/9414290/#{endpoint}", params: options
      expect(response).to have_http_status(:unprocessable_content)
    end
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'returns a readable 503 when height-reference metadata is unavailable' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290', station_name: 'San Francisco' }])
    stub_request(:get, /datums.json/).to_return(status: 503)
    get '/stations/9414290/report'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body['error']).to include('temporarily unavailable')
  end

  it 'returns 503 when datum metadata works but all data requests time out' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290', station_name: 'San Francisco' }])
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: 'MLLW' }] }.to_json)
    stub_request(:get, /sensors.json/).to_return(body: { sensors: [] }.to_json)
    stub_request(:get, /datagetter/).to_timeout
    get '/stations/9414290/report'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body['error']).to include('temporarily unavailable')
  end
end

# rubocop:enable RSpec/DescribeClass
