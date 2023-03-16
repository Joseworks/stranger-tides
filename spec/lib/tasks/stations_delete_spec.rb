# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'spec_helper'

describe 'stations_delete namespace rake delete_station_list' do
  describe 'delete_station_list' do
    before do
      load Rails.root.join('lib/tasks/stations_delete.rake')
      Rake::Task.define_task(:environment)
    end

    it 'deletes a station' do
      Station.create
      expect do
        Rake::Task['stations_delete:delete_station_list'].invoke
      end.to change(Station, :count).by(-1)
    end
  end
end
