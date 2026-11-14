# frozen_string_literal: true

module Noaa
  class StationReport
    DATA_PATH = '/api/prod/datagetter'
    HOURS = [24, 48, 72].freeze

    def initialize(station, hours: 48, units: 'english', client: nil)
      @station = station
      @hours = Integer(hours, exception: false)
      @units = units
      @client = client || Client.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20)
      raise NoData, 'Choose 24, 48, or 72 hours and feet or meters.' unless
        HOURS.include?(@hours) && %w[english metric].include?(@units)
    end

    def call
      @now = Time.current.utc.change(sec: 0)
      datum = reference
      observed = capable?('waterlevels') ? optional_data('water_level', datum:) : []
      prediction_interval = @station['prediction_type'] == 'S' ? 'hilo' : nil
      predicted = if capable?('tidepredictions')
                    optional_data('predictions', datum:, interval: prediction_interval)
                  else
                    []
                  end
      events = if capable?('tidepredictions')
                 optional_data('predictions', datum:, interval: 'hilo', future: true)
               else
                 []
               end
      latest = observed.rfind { |point| point[:value] }
      { station: @station, datum:, units: @units, hours: @hours, fetched_at: @now.iso8601,
        observations: observed, predictions: predicted, events: events,
        latest:, stale: latest.nil? || Time.iso8601(latest[:time]) < @now - 18.minutes,
        weather: weather, sensors: @sensors || [], warnings: @warnings || [],
        source_url: "https://tidesandcurrents.noaa.gov/stationhome.html?id=#{id}" }
    end

    private

    def id
      @station.fetch('station_id')
    end

    def capable?(type)
      @station.fetch('capabilities', []).include?(type)
    end

    def reference
      return nil unless capable?('waterlevels') || capable?('tidepredictions')
      return 'MLLW' unless capable?('waterlevels')

      datums = @client.get("/mdapi/prod/webapi/stations/#{id}/datums.json", {},
                           expires_in: 1.day).fetch('datums', [])
      names = Array(datums).filter_map { |datum| datum['name'] if datum.is_a?(Hash) }
      return 'IGLD' if names.intersect?(%w[IGLD GL_LWD])

      %w[MLLW MSL STND].find { |name| names.include?(name) } ||
        raise(NoData, 'NOAA has not published a supported height reference for this station.')
    end

    def optional_data(product, datum: nil, interval: nil, future: false)
      params = parameters(product, datum:, interval:, future:)
      payload = @client.get(DATA_PATH, params)
      rows = payload[product == 'predictions' ? 'predictions' : 'data']
      raise NoData, 'No recent observations are available.' unless rows.is_a?(Array)

      rows.filter_map { |row| observation(row, product) }.uniq { |point| point[:timestamp] }
          .sort_by { |point| point[:timestamp] }
    rescue NoData, Unavailable => e
      (@warnings ||= []) << { product:, message: e.message }
      []
    end

    def parameters(product, datum:, interval:, future:)
      params = { station: id, product:, units: @units, time_zone: 'gmt',
                 application: 'StrangerTides', format: 'json',
                 begin_date: (future ? @now : @now - @hours.hours).strftime('%Y%m%d %H:%M'),
                 end_date: (future ? @now + 24.hours : @now).strftime('%Y%m%d %H:%M') }
      params[:datum] = datum if datum
      params[:interval] = interval if interval
      params
    end

    def observation(row, product)
      return unless row.is_a?(Hash)

      time = Time.strptime("#{row.fetch('t')} +0000", '%Y-%m-%d %H:%M %z')
      value = Float(row[product == 'wind' ? 's' : 'v'], exception: false)
      { timestamp: (time.to_f * 1000).to_i, time: time.iso8601,
        value: value&.finite? ? value : nil, quality: row['q'], flags: row['f'],
        type: row['type'], direction: row['d'], gust: row['g'] }
    rescue KeyError, ArgumentError
      nil
    end

    def weather
      return {} unless capable?('waterlevelsandmet')

      @sensors = Sensors.new(id, client: @client).call
      @sensors.select { |sensor| sensor[:enabled] }.pluck(:product).index_with do |product|
        optional_data(product).rfind { |point| point[:value] }
      end.compact
    rescue NoData, Unavailable => e
      (@warnings ||= []) << { product: 'weather', message: e.message }
      {}
    end
  end
end
