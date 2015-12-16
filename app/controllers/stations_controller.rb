class StationsController < ApplicationController
  before_action :set_station, only: [:show, :edit, :update, :destroy]

  def show_station
    # Temporary override to ensure showing one station. Needs to receive from js the id of the station marker.
    @all_station_metadata = Station.last.metadata

    # tide_info = TideParsingService::TideProcessor.tide_level_retrieval(station_id, current_product, url)

    # time_stamp_info = TideParsingService::TideProcessor.time_stamp_retrieval(station_id, current_product, url)

    # tide_s_info = TideParsingService::TideProcessor.tide_s_retrieval(station_id, current_product, url)

    @chart =GraphProcessorService::GraphProcessor.graph_constructor(@all_station_metadata)

    #   @chart1 = GraphingService::ChartProcessor.grapher(@metadata.station_name, tide_s_info, time_stamp_info)

  end



  def show_stations
    @all_station_metadata = Station.last.metadata
    gon.all_station_metadata = @all_station_metadata
    @chart =GraphProcessorService::GraphProcessor.graph_constructor(@all_station_metadata)
    gon.chart = @chart
  end



  def show_graph
    @all_station_metadata = Station.last.metadata
    gon.all_station_metadata = @all_station_metadata
    @chart =GraphProcessorService::GraphProcessor.graph_constructor(@all_station_metadata)


    if request.xhr?
      respond_to do |format|
        format.js
      end
    end
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
      params.require(:station).permit(:station_id, :station_name, :latitude, :longitude, :tide_info, :metadata, :range_constructor)
    end
  end
