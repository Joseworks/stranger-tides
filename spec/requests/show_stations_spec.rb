# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ShowStations' do
  describe 'GET /show_graph' do
    it 'returns http success' do
      get '/show_stations'
      expect(response.has_http_status?(:success)).to be(true)
    end
  end
end
