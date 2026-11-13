# frozen_string_literal: true

require 'rails_helper'
# Request coverage spans the HTML explorer and its JSON API.
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Station explorer' do
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

  it 'returns a readable 503 when height-reference metadata is unavailable' do
    Station.create!(station_name: 'All stations',
                    metadata: [{ station_id: '9414290', station_name: 'San Francisco' }])
    stub_request(:get, /datums.json/).to_return(status: 503)
    get '/stations/9414290/report'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body['error']).to include('temporarily unavailable')
  end
end

# rubocop:enable RSpec/DescribeClass
