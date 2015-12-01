namespace :station_list do
  require 'open-uri'

  desc "Station List"
    task :process_station_list => :environment do
      @all_reporting_stations = []
      @all_reporting_stations = TideStation.parse_stations_id
      new_station = Station.find_or_create_by(station_name: "All stations")
      new_station.tide_info = @all_reporting_stations
      new_station.station_name = "All stations"
      new_station.save
    end

  class TideStation
    def self.parse_stations_id
      all_lines = []
      station_id_list = []
      station_list = File.join(Rails.root, 'data', 'station_list.txt')
      file = File.open(station_list, 'r') do |f|
        f.each do |line|
          all_lines << line
        end
      end
      all_lines.each do |line|
       station_id_list << line.split(' ').first.to_i
      end
      p "Done!"
      station_id_list
    end
  end

  desc "Delete Station List"
    task :delete_station_list => :environment do
      Station.delete_all
      p " All stations have been erased"
    end



  desc "Run Process"
    task :try_this => :environment do

    p " All stations!"
    @all_reporting_stations = Station.last.tide_info
    @all_charts = []
    @all_station_metadata = []

    @all_reporting_stations.each do |station_id|
      my_station = station_id
      product = 'water_level'
      begin_date = '20151120'
      begin_time ='10:00'
      end_date = '20151122'
      end_time ='10:24'
      datum = 'mllw'
      units='english'
      time_zone='gmt'
      application='web_services'
      format='json'


      constructed_station_params ={ my_station: my_station,
                                    product: product,
                                    begin_date: begin_date,
                                    begin_time: begin_time,
                                    end_date: end_date,
                                    end_time: end_time,
                                    datum: datum,
                                    units: units,
                                    time_zone: time_zone,
                                    application: application,
                                    format: format
                                  }
     @constructed_station = StationConstructor.new(constructed_station_params)
     @path_build = @constructed_station.url_constructor
      url = @path_build

      @metadata = TideParsingService::TideProcessor.metadata_retrieval(my_station, product, url)



      unless @metadata.nil?
        # gon.metadata = @metadata
        @all_station_metadata << @metadata
        tide_info = TideParsingService::TideProcessor.tide_level_retrieval(my_station, product, url)
        time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(my_station, product, url)
         # tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(my_station, product, url)
        @chart = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_info, time_stamp_info)
        @all_charts << @chart
        p @chart
      end

      # gon.all_station_metadata = @all_station_metadata


    end
  end

end
