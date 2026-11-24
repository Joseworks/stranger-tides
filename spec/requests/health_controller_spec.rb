# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController do
  def snapshot(age:, stations: [{ 'station_id' => '9414290' }])
    Station.create!(station_name: Noaa::Catalog::SNAPSHOT_NAME,
                    metadata: { retrieved_at: age.ago.iso8601, stations: })
  end

  it 'reports a fresh, populated catalog without requesting NOAA' do
    snapshot(age: 1.hour)
    get '/health/catalog'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('status' => 'ok')
    expect(response.headers['Cache-Control']).to include('no-store')
    expect(WebMock).not_to have_requested(:get, /noaa/)
  end

  it 'returns 503 if the catalog is older than two days' do
    snapshot(age: 3.days)
    get '/health/catalog'
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body['status']).to eq('attention_required')
  end

  it 'returns 503 when no saved catalog exists' do
    get '/health/catalog'
    expect(response).to have_http_status(:service_unavailable)
  end

  it 'does not report an empty catalog as healthy' do
    snapshot(age: 1.hour, stations: [])
    get '/health/catalog'
    expect(response).to have_http_status(:service_unavailable)
  end
end
