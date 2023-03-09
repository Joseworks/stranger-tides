# frozen_string_literal: true

# Retrieves the different products from the tide station. Currently retrieving only tide levels.

include ActiveModel::Model
require 'open-uri'

module TideParsingService
  class TideProcessor
    def self.url_validator(url)
      puts "--- URL ----- #{url}"
      URI.open(url)
    rescue Errno::ECONNREFUSED => e
      errors.add :station, "We can not connect to this url #{e.inspect}"
    rescue Errno::ENOENT => e
      errors.add :station,
                 "No such file or directory - does/not/exist #{e.inspect}"
    rescue Net::OpenTimeout => e
      errors.add :station, "Net::OpenTimeout: execution expired #{e.inspect}"
    rescue OpenURI::HTTPError => e
      unless e.message == "The service appears to be offline at #{Time.zone.now}404 Not Found"
        # raise e
        pp "ERROR ------ #{e.inspect}"
      end

      # TODO: handle 404 error
      Rails.logger.warn(e.message.inspect)
    end

    def self.metadata_parser!(url)
      URI.open(url) do |f|
        json_string = f.read
        parse_json = JSON.parse(json_string)['metadata']
        # binding.pry
        parse_json&.deep_symbolize_keys
      end
    end

    def self.datum_retrieval(station)
      datums = []
      url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/#{station}/datums.json"
      URI.open(url) do |f|
        json_string = f.read
        # binding.pry
        parse_json = JSON.parse(json_string)['datums']

        # p "parse_json.nil? --------- #{parse_json.nil?}"
        p "parse_json --------- #{parse_json}"
        parse_json&.select { |f| datums << f['name'] }
      end
      p "datums --------- #{datums}"
      datums
    end

    def self.metadata_retrieval(_my_station, _current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide = TideParsingService::TideProcessor.metadata_parser!(url_to_parse)
      print '.' unless parsed_tide.nil?
      # meta
      Metadata.new(parsed_tide) unless parsed_tide.nil?
    end

    def self.tide_level_retrieval(_my_station, _current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
      # tide_height
      TideParsingService::TideProcessor.param_v_parser(parsed_tide_info)
    end

    def self.tide_s_retrieval(_my_station, _current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
      # tide_s
      TideParsingService::TideProcessor.param_s_parser(parsed_tide_info)
    end

    def self.time_stamp_retrieval(_my_station, _current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
      # tide_time
      TideParsingService::TideProcessor.time_parser(parsed_tide_info)
    end

    def self.tide_level_parser!(url)
      URI.open(url) do |f|
        json_string = f.read
        parse_json = JSON.parse(json_string).deep_symbolize_keys
        parse_json.except(:metadata)[:data]
      end
    end

    def self.time_parser(info)
      param_t = []
      info&.each do |element|
        param_t << element[:t]
      end
      param_t
    end

    def self.param_v_parser(info)
      param_v = []
      unless info.nil?
        info.each do |element|
          param_v << element[:v].to_f
        end
        n = 1 # amount of samples per reading
        param_v.each_slice(n).map(&:last)
      end
      param_v.each_slice(n).map(&:last)
    end

    # not is use right now,
    # displays a different set of parameters read from the tide station.
    def self.param_s_parser(info)
      param_s = []
      unless info.nil?
        info.each do |element|
          param_s << element[:s].to_f
        end

        n = 8
        param_s.each_slice(n).map(&:last)
      end
      param_s.each_slice(n).map(&:last)
    end
  end

  class Metadata
    attr_accessor :station_id, :station_name, :latitude, :longitude

    def initialize(args)
      @station_id = args[:id]
      @station_name = args[:name]
      @latitude = args[:lat]
      @longitude = args[:lon]
    end
  end
end
