require 'spec_helper'
require 'rake'
require 'rails_helper'

describe 'station_list' do
  before do
    load File.join(Rails.root, 'lib', 'tasks', 'stations_metadata_list.rake')
    load File.join(Rails.root, 'lib', 'tasks', 'stations_id_list.rake')
    Rake::Task.define_task(:environment)
  end

  describe 'station_list:retrieve_all_stations_metadata' do
    it "retrieves all the stations metadata to a station" do
      Rake::Task["station_list:retrieve_all_stations_metadata"].invoke

      expect(Station.last.metadata).to include("station_id" => "9461380",
                                               "station_name" => "Adak Island",
                                               "latitude" => "51.8633",
                                               "longitude" => "-176.6320")
      expect(Station.last.metadata).to be_kind_of(Array)
    end
  end
end
