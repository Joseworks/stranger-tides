require 'rails_helper'

RSpec.describe "stations/show_stations", type: :view do
  before do
    assign(:stations, [
             Station.create!,
             Station.create!
           ])
  end

  it "renders a list of stations" do
    render
  end
end
