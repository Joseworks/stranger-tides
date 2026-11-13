# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShowStations' do
  describe 'GET /show_stations' do
    it 'returns http success' do
      get '/show_stations'

      expect(response).to have_http_status(:success)
    end

    it 'provides a fingerprinted marker icon to the map script' do
      get '/show_stations'

      expect(response.body).to match(/data-marker-icon="[^" ]*orange_marker[^" ]*\.png"/)
    end

    it 'renders the show_stations template' do
      get '/show_stations'

      expect(response).to render_template 'stations/show_stations'
    end
  end

  describe 'POST /show_graph' do
    before do
      post '/show_graph', params: { content: '1617433' },
                          headers: { 'X-Requested-With' => 'XMLHttpRequest',
                                     'Accept' => 'text/javascript' }
    end

    it 'responds successfully' do
      expect(response).to have_http_status(:success)
    end

    it 'responds with JavaScript' do
      expect(response.media_type).to eq('text/javascript')
    end

    it 'renders the selected station chart' do
      expect(response.body).to include('Highcharts', 'Kawaihae', 'tide-graph')
    end
  end
end
