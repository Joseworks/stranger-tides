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


  def self.metadata_retrieval(my_station, current_product, url_to_parse)
    TideParsingService::TideProcessor.url_validator(url_to_parse)
    parsed_tide = TideParsingService::TideProcessor.metadata_parser!(url_to_parse).deep_symbolize_keys
    # my_metadata =  TideParsingService::Metadata.new(parsed_tide)
  end

  def self.tide_level_retrieval(my_station, current_product, url_to_parse)
    TideParsingService::TideProcessor.url_validator(url_to_parse)
    # parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse).deep_symbolize_keys
    parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)#.deep_symbolize_keys
    tide_time = TideParsingService::TideProcessor.time_parser(parsed_tide_info)
    tide_height = TideParsingService::TideProcessor.param_v_parser(parsed_tide_info)
    # ayudame
  end

  def self.time_stamp_retrieval(my_station, current_product, url_to_parse)
    TideParsingService::TideProcessor.url_validator(url_to_parse)
    parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)#.deep_symbolize_keys
    tide_time = TideParsingService::TideProcessor.time_parser(parsed_tide_info)
  end


  def self.ayudame
    p " I am here <=============="
  end


end
