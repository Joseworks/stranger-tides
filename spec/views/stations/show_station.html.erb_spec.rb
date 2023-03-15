# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'stations/show_stations' do
  before do
    @station = assign(:station, Station.create!)
  end

  it 'renders attributes in <p>' do
    render
  end
end
