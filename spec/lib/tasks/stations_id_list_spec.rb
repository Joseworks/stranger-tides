require 'spec_helper'
require 'rake'
require 'rails_helper'

describe 'stations_id_list' do
  before do
    load File.join(Rails.root, 'lib', 'tasks', 'stations_id_list.rake')
    Rake::Task.define_task(:environment)
    Rake::Task["stations_id_list:process_station_list"].invoke
  end

  describe 'stations_id_list:process_station_list' do
    it "adds all the stations ids to a station" do
      expect(Station.last.tide_info).to include("9461710")
      expect(Station.last.tide_info).not_to be_nil
    end
  end
end
