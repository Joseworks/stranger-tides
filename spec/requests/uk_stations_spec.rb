# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'UK tide-gauge endpoints' do
  let(:origin) { EnvironmentAgency::Client::ORIGIN + EnvironmentAgency::Client::ROOT }

  before do
    measure = { parameter: 'level', qualifier: 'Tidal Level', period: 900, unitName: 'mAOD' }
    station = { stationReference: 'E70039', label: 'Lowestoft', lat: 52.47, long: 1.75,
                status: 'api/statusActive', measures: [measure] }
    stub_request(:get, "#{origin}/id/stations")
      .with(query: hash_including('type' => 'TideGauge'))
      .to_return(body: { items: [station] }.to_json)
  end

  it 'serves a UK catalog without NOAA requests, database writes or credentials' do
    expect { get '/stations.json', params: { network: 'uk' } }.not_to change(Station, :count)
    expect(response.parsed_body['stations'].first['station_id']).to eq('ea-E70039')
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'rejects unsupported products and networks' do
    %w[photo context nearby].each do |product|
      get "/stations/ea-E70039/#{product}"
      expect(response).to have_http_status(:unprocessable_content)
    end
    get '/stations.json', params: { network: 'invalid' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'keeps NOAA catalog usable when the optional UK network fails' do
    stub_request(:get, "#{origin}/id/stations").with(query: hash_including('type' => 'TideGauge'))
                                               .to_return(status: 503)
    get '/stations.json', params: { network: 'all' }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['network_warnings']).to include(/Environment Agency/)
  end
end
