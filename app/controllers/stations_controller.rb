class StationsController < ApplicationController
  before_action :set_station, only: [:show, :edit, :update, :destroy]

  def show_station
    my_station = 8723214
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
    # url = "http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=#{begin_date} #{begin_time}&end_date=#{end_date} #{end_time}&station=#{my_station}&product=#{product}&datum=#{datum}&units=#{units}&time_zone=#{time_zone}&application=#{application}&format=#{format}"

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
# p " =======  IT IS THE TRUTH!!!" if @constructed_station.url_constructor.valid?

   url = @path_build
# Trying to change the way metadata is consumed to a class
    # this metadata_retrieval needs to be a service
    @metadata = TideParsingService::TideProcessor.metadata_retrieval(my_station, product, url) #( And now it is an object.)
    gon.metadata = @metadata
    # gon.metadata = @metadata



# Now Trying to change the way tide_info is consumed to a class
# the purpose of this is to eliminate active record per se and migrate to PORO's

    tide_info = TideParsingService::TideProcessor.tide_level_retrieval(my_station, product, url)
    time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(my_station, product, url)

     tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(my_station, product, url)



# Graphing away!
    @chart = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_info, time_stamp_info)

    @chart1 = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_s_info, time_stamp_info)
 # The purpose of the url constructor is to have a user interface to enter params without an active record model.

  end





def show_stations
            # HardWorker.perform_in(1.minute, 'bob', 5)

    HardWorker.perform_async('bob', 5)



   # @all_reporting_stations = Station.last.tide_info
   @all_reporting_stations = StationListService::TideStation.parse_stations_id
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
      gon.metadata = @metadata
      @all_station_metadata << @metadata
      tide_info = TideParsingService::TideProcessor.tide_level_retrieval(my_station, product, url)
      time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(my_station, product, url)
       # tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(my_station, product, url)
      @chart = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_info, time_stamp_info)
      @all_charts << @chart
    end
  end
  gon.all_station_metadata = @all_station_metadata
end

















  # GET /stations
  # GET /stations.json
  def index
    @stations = Station.all
  end

  # GET /stations/1
  # GET /stations/1.json
  def show
    my_station = 8454000
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
    url = "http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=#{begin_date} #{begin_time}&end_date=#{end_date} #{end_time}&station=#{my_station}&product=#{product}&datum=#{datum}&units=#{units}&time_zone=#{time_zone}&application=#{application}&format=#{format}"



 # The purpose of the url constructor is to have a user interface to enter params without an active record model.

    url_params = {my_station: my_station, product: product, begin_date: begin_date, end_date: end_date}
    uri = TideParsingService::UrlConstructor.new(url_params)

p " ==========#{uri.constructed_url}======"


# Trying to change the way metadata is consumed to a class
    # this metadata_retrieval needs to be a service
    metadata = TideParsingService::TideProcessor.metadata_retrieval(my_station, product, url) #( And now it is! (W00T!)



    meta = TideParsingService::Metadata.new(metadata)


# Now Trying to change the way tide_info is consumed to a class
# the purpose of this is to eliminate active record per se and migrate to PORO's

    tide_info = TideParsingService::TideProcessor.tide_level_retrieval(my_station, product, url)
    time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(my_station, product, url)

    @chart = GraphingService::ChartProcessor.grapher(meta.station_name, tide_info, time_stamp_info)
  end

  # GET /stations/new
  def new
    @station = Station.new
  end

  # GET /stations/1/edit
  def edit
  end

  # POST /stations
  # POST /stations.json
  def create

    @station = Station.new(station_params)

    respond_to do |format|
      if @station.save
        format.html { redirect_to @station, notice: 'Station was successfully created.' }
        format.json { render :show, status: :created, location: @station }
      else
        format.html { render :new }
        format.json { render json: @station.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stations/1
  # PATCH/PUT /stations/1.json
  def update
    respond_to do |format|
      if @station.update(station_params)
        format.html { redirect_to @station, notice: 'Station was successfully updated.' }
        format.json { render :show, status: :ok, location: @station }
      else
        format.html { render :edit }
        format.json { render json: @station.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stations/1
  # DELETE /stations/1.json
  def destroy
    @station.destroy
    respond_to do |format|
      format.html { redirect_to stations_url, notice: 'Station was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_station
      @station = Station.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def station_params
      params.require(:station).permit(:station_id, :station_name, :latitude, :longitude, :tide_info)    end
end
