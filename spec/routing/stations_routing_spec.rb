# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StationsController do
  describe 'routing' do
    it 'routes to #show_stations' do
      expect(get: '/show_stations', xhr: true).to route_to('stations#show_stations')
    end

    it 'routes to #show_graph' do
      expect(post: '/show_graph', xhr: true).to route_to('stations#show_graph')
    end
  end
end
