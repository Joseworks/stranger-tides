# frozen_string_literal: true

# Retrieves the different products from the tide station.
# Currently retrieving only tide levels.

module TideParsingService
  class TideProcessor
    def self.url_validator(url)
      response = Faraday.get(url)
      return unless [400, 403, 500].include?(response.status)

      e.add :station, "We can not connect to this url #{e.inspect}"
    rescue Errno::ECONNREFUSED => e
      e.add :station, "We can not connect to this url #{e}"
    rescue Errno::ENOENT => e
      e.add :station, "No such file or directory - does/not/exist #{e}"
    rescue Net::OpenTimeout => e
      e.add :station, "Net::OpenTimeout: execution expired #{e}"
    rescue OpenURI::HTTPError => e
      er = "The service appears to be offline at #{Time.zone.now} 404 Not Found"
      Rails.logger.debug { "ERROR ------ #{e}" } unless e.message == er

      # TODO: handle 404 error
      Rails.logger.warn(e.message.inspect)
    end

    def self.metadata_parser!(url)
      conn = Faraday::Connection.new
      json_string = conn.get url, accept: 'application/json'

      parse_json = JSON.parse(json_string.body)['metadata']

      parse_json&.deep_symbolize_keys
    end

    def self.datum_retrieval(station)
      datums = []
      url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/#{station}/datums.json"

      conn = Faraday::Connection.new
      json_string = conn.get url, accept: 'application/json'
      parse_json = JSON.parse(json_string.body)['datums']
      parse_json&.select { |f| datums << f['name'] }
      datums
    end

    def self.metadata_retrieval(_my_station, _current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide = TideParsingService::TideProcessor.metadata_parser!(url_to_parse)
      Rails.logger.debug '.' unless parsed_tide.nil?
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
      conn = Faraday::Connection.new
      json_string = conn.get url, accept: 'application/json'

      parse_json = JSON.parse(json_string.body).deep_symbolize_keys

      parse_json.except(:metadata)[:data]
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

    # not in use currently,
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
