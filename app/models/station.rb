class Station < ActiveRecord::Base
  require 'open-uri'
  # attr_accessor :station_id, :station_name, :latitude, :longitude, :tide_info
  # def initialize(args)
  #   @station_id = args[:id]
  #   @station_name = args[:name]
  #   @latitude = args[:lat]
  #   @longitude = args[:lon]
  #   @tide_info = ''
  # end


  def self.metadata_retrieval
    url_to_parse = 'http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=20151109 10:00&end_date=20151110 10:24&station=8454000&product=water_level&datum=mllw&units=english&time_zone=gmt&application=web_services&format=json'
    # url_to_parse = nil

    TideParsingService::TestTide.url_validator(url_to_parse)
    parsed_tide = TideParsingService::TestTide.metadata_parser!(url_to_parse).deep_symbolize_keys
    # my_metadata =  TideParsingService::Metadata.new(parsed_tide)



  end



end
