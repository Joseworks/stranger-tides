class StationConstructor
    attr_accessor :my_station,:product,:begin_date,:begin_time,:end_date,:end_time,:datum,:units,:time_zone,:application,:format,:url
    def initialize(args)
      @my_station = args[:my_station]
      @product = args[:product]
      @begin_date = args[:begin_date]
      @begin_time = args[:begin_time]
      @end_date = args[:end_date]
      @end_time = args[:end_time]
      @datum = args[:datum]
      @units = args[:units]
      @time_zone = args[:time_zone]
      @application = args[:application]
      @format = args[:format]
    end

  def url_formador
     "http://tidesandcurrents.noaa.gov/api/datagetter?begin_date=#{@begin_date} #{@begin_time}&end_date=#{@end_date} #{@end_time}&station=#{@my_station}&product=#{@product}&datum=#{@datum}&units=#{@units}&time_zone=#{@time_zone}&application=#{@application}&format=#{@format}"
  end

    def url_constructor
     URI::HTTP.build({:host => "www.tidesandcurrents.noaa.gov",
                      :query => { :begin_date => @begin_date }.to_query,
                      :path => "/api/datagetter"})
   end


end
