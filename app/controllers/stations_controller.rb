class StationsController < ApplicationController
  before_action :set_station, only: [:show, :edit, :update, :destroy]

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
    begin_date = '20151110'
    begin_time ='10:00'
    end_date = '20151122'
    end_time ='10:24'
    datum = 'mllw'
    units='english'
    time_zone='gmt'
    application='web_services'
    format='json'
    url = "http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=#{begin_date} #{begin_time}&end_date=#{end_date} #{end_time}&station=#{my_station}&product=#{product}&datum=#{datum}&units=#{units}&time_zone=#{time_zone}&application=#{application}&format=#{format}"




    url_params = {my_station: my_station, product: product, begin_date: begin_date, end_date: end_date}
    uri = TideParsingService::UrlConstructor.new(url_params)

p " ==========#{uri.contructed_url}======"

    url = "http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=#{begin_date} #{begin_time}&end_date=#{end_date} #{end_time}&station=#{my_station}&product=#{product}&datum=#{datum}&units=#{units}&time_zone=#{time_zone}&application=#{application}&format=#{format}"



    metadata = Station.metadata_retrieval(my_station, product, url)
    tide_info = Station.tide_level_retrieval(my_station, product, url)
    time_stamp_info = Station.time_stamp_retrieval(my_station, product, url)
    # p "====================#{time_stamp_info.inspect}======================================="
    @station = Station.new
    @station.station_name = metadata[:name]
    @station.station_id = metadata[:id]
    @station.latitude = metadata[:lat]
    @station.longitude = metadata[:lon]
    @station.save!
    @chart = GraphingService::ChartProcessor.grapher(@station.station_name, tide_info, time_stamp_info)
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
