include ActiveModel::Model

module TideParsingService

  class TestTide

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