include ActiveModel::Model
require 'open-uri'
module TideParsingService

  class TideProcessor

    def self.url_validator(url)
      begin
        file = open(url)
      rescue Errno::ECONNREFUSED
        self.errors.add :station, 'We can not connect to this url'
      rescue Errno::ENOENT
        self.errors.add :station, 'No such file or directory - does/not/exist'
      rescue
        self.errors.add :station, 'This url can not be parsed'
      end
    end

    def self.metadata_parser!(url)
      open(url) do |f|
        json_string = f.read
        parse_json = JSON.parse(json_string)['metadata']
        # p "parse_json #{parse_json.inspect}"

        parse_json.deep_symbolize_keys unless parse_json.nil?
      end
    end


    def self.metadata_retrieval(my_station, current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide = TideParsingService::TideProcessor.metadata_parser!(url_to_parse)
      # p "parsed_tide #{parsed_tide.inspect}"
      meta = Metadata.new(parsed_tide) unless parsed_tide.nil?
    end



    def self.tide_level_retrieval(my_station, current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
      tide_height = TideParsingService::TideProcessor.param_v_parser(parsed_tide_info)
    end





    def self.tide_s_retrieval(my_station, current_product, url_to_parse)
      url_validator(url_to_parse)
      parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
      tide_s = TideParsingService::TideProcessor.param_s_parser(parsed_tide_info)
    end




  def self.time_stamp_retrieval(my_station, current_product, url_to_parse)
    url_validator(url_to_parse)
    parsed_tide_info = TideParsingService::TideProcessor.tide_level_parser!(url_to_parse)
    tide_time = TideParsingService::TideProcessor.time_parser(parsed_tide_info)
  end






    def self.tide_level_parser!(url)
      open(url) do |f|
        json_string = f.read
        parse_json = JSON.parse(json_string).deep_symbolize_keys
        parse_json.except(:metadata)[:data]
      end
    end


    def self.time_parser(info)
      param_t =[]
        unless info.nil?
        info.each do |element|
          param_t << element[:t]
        end
      end
      param_t
    end

    def self.param_v_parser(info)
      param_v =[]
      # p "info #{info.inspect}"
      unless info.nil?
        info.each do |element|
          param_v << element[:v].to_f
        end
        param_v
        n = 8 #amount of samples per reading
        param_v.each_slice(n).map(&:last)
      end
      # p "I got here because there is some metadata"
      # param_v
      param_v.each_slice(n).map(&:last)

    end

#not is use right now
    def self.param_s_parser(info)
      param_s =[]
      unless info.nil?
        info.each do |element|
          param_s << element[:s].to_f
        end
        param_s
        n = 8
        param_s.each_slice(n).map(&:last)
      end
      # param_s
      param_s.each_slice(n).map(&:last)

    end
  end






  class UrlConstructor
    attr_accessor :station_id, :station_name, :latitude, :longitude
    def initialize(args)
      @my_station = args[:my_station]
      @product = args[:product]
      @begin_date = args[:begin_date]
      @end_date = args[:end_date]
    end

    def constructed_url
     URI::HTTP.build({:host => "www.tidesandcurrents.noaa.gov", :query => { :begin_date => @begin_date }.to_query, :path => "/api/datagetter"})
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