require 'spec_helper'
require 'rake'
require 'rails_helper'

describe 'station_list' do
    before do
      load File.join(Rails.root, 'lib', 'tasks', 'station_list.rake')
      Rake::Task.define_task(:environment)
    end
  describe 'station_list:delete_station_list' do
    it "should delete a station" do
        expect {
          Rake::Task["station_list:process_station_list"].invoke
        }.to change(Station, :count).by(1)

        expect {
          Rake::Task["station_list:delete_station_list"].invoke
        }.to change(Station, :count).by(-1)

    end

  end

  describe 'station_list:parse_stations_id' do
    it "should add all the stations ids to a station" do
        station = Station.new

        Rake::Task["station_list:parse_stations_id"].invoke
        expect (station.tide_info).to include("9461710")

    end
  end
end


