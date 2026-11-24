# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'Historical station data' do
  before do
    Station.create!(station_name: 'All stations', metadata: [
                      { station_id: '9414290', station_name: 'San Francisco',
                        capabilities: ['waterlevels'] }
                    ])
  end

  it 'validates station IDs and date options before any outbound request' do
    ['/stations/9999999/history', '/stations/9414290/history'].each do |path|
      get path, params: { begin_date: 'invalid', end_date: '2020-01-01' }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
    end
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'returns historical JSON with an explicit resolution and height reference' do
    stub_request(:get, /datums.json/).to_return(body: { datums: [{ name: 'MLLW' }] }.to_json)
    stub_request(:get, /datagetter/).with(query: hash_including('product' => 'hourly_height'))
                                    .to_return(body: { data: [{ t: '2020-01-01 00:00',
                                                                v: '0' }] }.to_json)
    get '/stations/9414290/history', params: { begin_date: '2020-01-01',
                                               end_date: '2020-06-30', units: 'metric' }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('datum' => 'MLLW', 'units' => 'metric',
                                            'window' => hash_including('resolution' => 'hourly'))
    expect(response.parsed_body['observations'].first['value']).to eq(0.0)
  end
end
