require 'rails_helper'
require 'spec_helper'
require 'rake'

describe 'stations_delete namespace rake delete_station_list' do
  describe 'delete_station_list' do
    before do
      load File.join(Rails.root, 'lib', 'tasks', 'stations_delete.rake')
      Rake::Task.define_task(:environment)
    end

    it "deletes a station" do
      Station.create
      expect do
        Rake::Task["stations_delete:delete_station_list"].invoke
      end.to change(Station, :count).by(-1)
    end
  end
end
