# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'stations/show_stations' do
  it 'offers station search and a non-JavaScript NOAA link' do
    render
    expect(rendered).to include('Find a station', 'Browse NOAA', 'station-search')
  end
end
