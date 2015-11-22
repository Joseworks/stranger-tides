include ActiveModel::Model

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
      end
    end

    def self.tide_level_parser!(url)
      # timerodeador =[]
      # param_v =[]
      param_s =[]
      param_f =[]
      param_q =[]
      open(url) do |f|
        json_string = f.read
        parse_json = JSON.parse(json_string).deep_symbolize_keys
        # info = parse_json.except(:metadata)[:data]
        parse_json.except(:metadata)[:data]
        # info.each do |elto|
        #   timerodeador << elto[:t]
        #   # param_v << elto[:v]
        #   # param_s << elto[:s]
        #   # param_f << elto[:f]
        #   # param_q << elto[:q]
        #   # p  "\n"
        # end
      end
      # array_of_tide_info =
      # p timerodeador
      # p param_v
      # p param_s
      # p param_f
      # p param_q
    end

    def self.time_parser(info)
      timerodeador =[]
      info.each do |elto|
        timerodeador << elto[:t]
      end
      timerodeador
    end

    def self.param_v_parser(info)
      param_v =[]
      info.each do |elto|
        param_v << elto[:v]
      end
      param_v
    end
  # create arrays inside another class here like metadata?


  end




# Not in use as is
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