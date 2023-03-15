# frozen_string_literal: true

# Forms the API request.

class StationConstructor
  include ActiveModel::Validations

  def initialize(args)
    @station = args[:my_station]
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

  def url_constructor
    URI::HTTPS.build(host: 'api.tidesandcurrents.noaa.gov',
                     query: { begin_date:,
                              end_date:,
                              station:,
                              product:,
                              datum:,
                              units:,
                              time_zone:,
                              application:,
                              format: }.to_query,
                     path: '/api/prod/datagetter')
  end

  attr_accessor :station,
                :product,
                :begin_date,
                :begin_time,
                :end_date,
                :end_time,
                :datum,
                :units,
                :time_zone,
                :application,
                :format,
                :url
end
