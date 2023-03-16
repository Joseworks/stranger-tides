# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'spec_helper'

describe 'station_list' do
  before do
    load Rails.root.join('lib/tasks/stations_metadata_list.rake')
    load Rails.root.join('lib/tasks/stations_id_list.rake')
    Rake::Task.define_task(:environment)
  end

  describe 'station_list:retrieve_all_stations_metadata' do
    let(:station_response) do
      [
        {
          'station_id' => '9461710',
          'station_name' => 'Atka',
          'latitude' => '52.2319',
          'longitude' => '-174.1725'
        },
        {
          'station_id' => '9461380',
          'station_name' => 'Adak Island',
          'latitude' => '51.8606',
          'longitude' => '-176.6376'
        }
      ]
    end

    it 'retrieves all the stations metadata to a station' do
      Rake::Task['station_list:retrieve_all_stations_metadata'].invoke
      expect(Station.last.metadata.include?(station_response.first)).to be(true)
    end

    it 'returns an array' do
      Rake::Task['station_list:retrieve_all_stations_metadata'].reenable
      Rake::Task['station_list:retrieve_all_stations_metadata'].invoke

      expect(Station.last.metadata.is_a?(Array)).to be(true)
    end
  end
end
