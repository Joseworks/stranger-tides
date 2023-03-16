# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShowStations' do
  describe 'GET /show_graph' do
    it 'returns http success' do
      get '/show_stations'

      expect(response).to have_http_status(:success)
    end

    it 'renders the show_stations template' do
      get '/show_stations'

      expect(response).to render_template 'stations/show_stations'
    end
  end
end
