# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'stations/show_stations' do
  it 'labels observation history, units, and time controls' do
    render
    expect(rendered).to include('history-hours', 'height-units', 'display-zone')
  end
end
