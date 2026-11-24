# frozen_string_literal: true

module Noaa
  class StationReport
    DATA_PATH = '/api/prod/datagetter'
    HOURS = [24, 48, 72, 168, 720].freeze
    FUTURE_HOURS = [0, 24, 72, 168, 720].freeze

    def initialize(station, hours: 48, units: 'english', future_hours: 0, client: nil)
      @station = station
      @hours = Integer(hours, exception: false)
      @units = units
      @future_hours = Integer(future_hours, exception: false)
      @client = client || Client.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20)
      raise NoData, 'Choose a supported history, planning period and unit system.' unless
        HOURS.include?(@hours) && FUTURE_HOURS.include?(@future_hours) &&
        %w[english metric].include?(@units)
    end

    def call
      @now = Time.current.utc.change(sec: 0)
      datum = reference
      water = water_data(datum)
      weather_series = weather
      raise @transport_error if @transport_error && !@received_data

      water.merge(station: @station, datum:, units: @units, hours: @hours,
                  fetched_at: @now.iso8601, future_hours: @future_hours,
                  stale: water[:latest].nil? ||
                    Time.iso8601(water[:latest][:time]) < @now - 18.minutes,
                  weather: Series.latest(weather_series),
                  station_timezone: StationTimeZone.new(id, client: @client).call,
                  weather_series:, sensors: @sensors || [], warnings: @warnings || [],
                  failed_products: @failed_products || [],
                  source_url: "https://tidesandcurrents.noaa.gov/stationhome.html?id=#{id}")
    end

    private

    def id = @station.fetch('station_id')

    def capable?(type) = @station.fetch('capabilities', []).include?(type)

    def water_data(datum)
      observed = if capable?('waterlevels')
                   optional_data('water_level', datum:, stream: 'observations')
                 else
                   []
                 end
      predicted = predictions(datum)
      { observations: observed, predictions: predicted,
        future_predictions: future_predictions(datum), events: predictions(datum, future: true),
        latest: observed.rfind { |point| point[:value] },
        differences: Series.differences(observed, predicted,
                                        subordinate: @station['prediction_type'] == 'S') }
    end

    def predictions(datum, future: false, events: true)
      return [] unless capable?('tidepredictions')

      interval = (future && events) || @station['prediction_type'] == 'S' ? 'hilo' : nil
      stream = 'predictions'
      stream = events ? 'events' : 'future_predictions' if future
      optional_data('predictions', datum:, interval:, future:, stream:)
    end

    def future_predictions(datum)
      @future_hours.positive? ? predictions(datum, future: true, events: false) : []
    end

    def reference
      WaterLevelDatum.new(@station, client: @client).call
    end

    def optional_data(product, datum: nil, interval: nil, future: false, stream: product)
      params = parameters(product, datum:, interval:, future:)
      payload = @client.get(DATA_PATH, params)
      rows = payload[product == 'predictions' ? 'predictions' : 'data']
      raise NoData, 'No recent observations are available.' unless rows.is_a?(Array)

      @received_data = true

      rows.filter_map { |row| Series.observation(row, product) }.uniq { |point| point[:timestamp] }
          .sort_by { |point| point[:timestamp] }
    rescue NoData, Unavailable => e
      record_failure(product, e, stream:)
      []
    end

    def parameters(product, datum:, interval:, future:)
      params = { station: id, product:, units: @units, time_zone: 'gmt',
                 application: 'StrangerTides', format: 'json',
                 begin_date: (future ? @now : @now - @hours.hours).strftime('%Y%m%d %H:%M'),
                 end_date: (future ? @now + [@future_hours, 24].max.hours : @now)
                           .strftime('%Y%m%d %H:%M') }
      params[:datum] = datum if datum
      params[:interval] = interval if interval
      params
    end

    def weather
      return {} unless capable?('waterlevels') || capable?('waterlevelsandmet')

      @sensors = Sensors.new(id, client: @client).call
      series = @sensors.select { |sensor| sensor[:enabled] }.pluck(:product).index_with do |product|
        optional_data(product, stream: "weather_series.#{product}")
      end
      series['specific_gravity'] = Series.specific_gravity(series['salinity']) if series['salinity']
      series
    rescue NoData, Unavailable => e
      record_failure('weather', e)
      {}
    end

    def record_failure(product, error, stream: product)
      @transport_error = error if error.is_a?(Unavailable)
      (@failed_products ||= []) << stream if error.is_a?(Unavailable)
      (@warnings ||= []) << { product:, message: error.message }
    end
  end
end
