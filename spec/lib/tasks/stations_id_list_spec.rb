# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'spec_helper'

describe 'stations_id_list' do
  before do
    load File.join(Rails.root, 'lib', 'tasks', 'stations_id_list.rake')
    Rake::Task.define_task(:environment)
    Rake::Task['stations_id_list:process_station_list'].invoke
  end

  describe 'stations_id_list:process_station_list' do
    it 'adds all the stations ids to a station' do
      expect(Station.last.tide_info.include?('9461710')).to be(true)
      expect(Station.last.tide_info.nil?).to be(false)
    end
  end
end
