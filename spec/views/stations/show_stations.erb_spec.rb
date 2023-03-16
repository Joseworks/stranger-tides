# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'stations/show_stations' do
  before do
    assign(:stations, [Station.create!, Station.create!])
  end

  it 'renders a list of stations' do
    expect(
      render.include?('NOAA/NOS/Operational Oceanographic Products Active Station')
    ).to be(true)
  end
end
