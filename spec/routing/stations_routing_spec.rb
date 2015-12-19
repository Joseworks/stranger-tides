require "rails_helper"

RSpec.describe StationsController, type: :routing do
  describe "routing" do
    it "routes to #show_stations" do
      expect(:get => "/show_stations").to route_to("stations#show_stations")
    end

    it "routes to #show_station" do
      expect(:get => "/show_station").to route_to("stations#show_station")
    end

    it "routes to #show_graph" do
      expect(:post => "/show_graph").to route_to("stations#show_graph")
    end
  end
end
