# frozen_string_literal: true

class TideStationHandler
  def initialize
    @all_lines = []
    @station_id_list = []
    @station_list = Rails.root.join('data/station_list.txt')
    return unless Rails.env.test?

    @station_list = Rails.root.join('spec/fixtures/station_list_fixture.txt')
  end

  def parse_stations_id
    File.open(station_list, 'r') do |f|
      f.each do |line|
        all_lines << line
      end
    end
    all_lines.each do |line|
      station_id_list << line.split.first.to_i
    end
    Rails.logger.debug 'Done!'
    station_id_list
  end

  attr_accessor :all_lines, :station_id_list, :station_list
end
