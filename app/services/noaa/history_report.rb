# frozen_string_literal: true

module Noaa
  class HistoryReport
    def initialize(station, units: 'english', client: nil, **window)
      @window = HistoryWindow.new(**window)
      raise NoData, 'Choose US or metric units.' unless %w[english metric].include?(units)

      @station = station
      @units = units
      @client = client || Client.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20)
      @warnings = []
    end

    def call
      datum = WaterLevelDatum.new(@station, client: @client).call
      observed = capable?('waterlevels') ? retrieve(@window.product, datum) : []
      predicted = predictions(datum)
      raise @transport_error if @transport_error && observed.empty? && predicted.empty?

      { station: @station, units: @units, datum:, window: @window.metadata,
        observations: observed, predictions: predicted,
        differences: Series.differences(observed, predicted,
                                        subordinate: @station['prediction_type'] == 'S'),
        warnings: @warnings, fetched_at: Time.current.utc.iso8601,
        source_url: "https://tidesandcurrents.noaa.gov/stationhome.html?id=#{id}" }
    end

    private

    def id = @station.fetch('station_id')

    def capable?(type) = @station.fetch('capabilities', []).include?(type)

    def predictions(datum)
      return [] if @window.monthly? || !capable?('tidepredictions')

      interval = @window.resolution == 'hourly' ? 'h' : '6'
      interval = 'hilo' if @station['prediction_type'] == 'S'
      retrieve('predictions', datum, interval:)
    end

    def retrieve(product, datum, interval: nil)
      params = @window.parameters.merge(station: id, product:, datum:, units: @units,
                                        time_zone: 'gmt', application: 'StrangerTides',
                                        format: 'json')
      params[:interval] = interval if interval
      payload = @client.get(StationReport::DATA_PATH, params, expires_in: 1.hour)
      rows = payload[product == 'predictions' ? 'predictions' : 'data']
      unless rows.is_a?(Array)
        raise NoData, 'NOAA has no historical data for this product and period.'
      end

      rows.filter_map { |row| history_point(row, product) }.select { |p| @window.include?(p) }
          .uniq { |point| point[:timestamp] }.sort_by { |point| point[:timestamp] }
    rescue NoData, Unavailable => e
      @transport_error = e if e.is_a?(Unavailable)
      @warnings << { product:, message: e.message }
      []
    end

    def history_point(row, product)
      return Series.observation(row, product)&.merge(quality: 'v') if product == 'hourly_height'
      return Series.observation(row, product) unless product == 'monthly_mean'
      return unless row.is_a?(Hash)

      date = Date.new(Integer(row.fetch('year')), Integer(row.fetch('month')), 1)
      point = Series.observation({ 't' => date.strftime('%Y-%m-%d 00:00'), 'v' => row['MSL'],
                                   'q' => 'v', 'f' => row['inferred'] }, product)
      point&.merge(period: date.strftime('%Y-%m'))
    rescue KeyError, ArgumentError, TypeError
      nil
    end
  end
end
