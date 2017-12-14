require 'rails_helper'

RSpec.describe "stations/show_stations", type: :view do
  before do
    @station = assign(:station, Station.create!)
  end

  it "renders attributes in <p>" do
    render
  end
end
