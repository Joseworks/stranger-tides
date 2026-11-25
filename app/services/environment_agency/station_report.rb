# frozen_string_literal: true

module EnvironmentAgency
  class StationReport
    HOURS = [24, 48, 72, 168, 672].freeze

    def initialize(station, hours: 48, units: 'english', client: Client.new, **_unused)
      @station = station
      @hours = Integer(hours, exception: false)
      @units = units
      @client = client
      raise Noaa::NoData, 'Choose a supported UK history period (up to 28 days) and units.' unless
        HOURS.include?(@hours) && %w[english metric].include?(@units)
    end

    def call
      now = Time.current.utc.change(sec: 0)
      observations = readings(now - @hours.hours, now)
      latest = observations.rfind { |point| point[:value] }
      { station: @station, units: @units, datum: @station.fetch('datum'), hours: @hours,
        observations:, latest:,
        stale: latest.nil? || Time.iso8601(latest[:time]) < now - 45.minutes,
        stale_after_minutes: 45, interval_minutes: 15,
        predictions: [], future_predictions: [],
        future_hours: 0, differences: [], events: [], weather: {}, weather_series: {}, sensors: [],
        warnings: [], failed_products: [], fetched_at: now.iso8601,
        station_timezone: 'Europe/London', source_name: 'Environment Agency',
        source_url: @station.fetch('source_url'), attribution: Catalog::ATTRIBUTION }
    end

    def readings(first, last)
      params = { startdate: first.to_date.iso8601, enddate: last.to_date.iso8601,
                 unitName: @station.fetch('source_unit'), _sorted: '', _limit: 3000 }
      rows = @client.get("/id/stations/#{@station.fetch('source_id')}/readings",
                         params).fetch('items')
      raise Noaa::Unavailable, 'The UK readings response is truncated. Try a shorter period.' if
        rows.length >= 3000

      rows.filter_map { |row| observation(row, first, last) }.uniq { |point| point[:timestamp] }
          .sort_by { |point| point[:timestamp] }
    end

    private

    def observation(row, first, last)
      return unless row.is_a?(Hash) && row['dateTime'].is_a?(String)

      time = Time.iso8601(row['dateTime']).utc
      return unless time.between?(first, last)

      value = row['value'].is_a?(Numeric) ? row['value'].to_f : nil
      value = nil unless value&.finite?
      value /= 0.3048 if value && @units == 'english'
      { time: time.iso8601, timestamp: time.to_i * 1000, value:, quality: nil, flags: nil }
    rescue ArgumentError
      nil
    end
  end
end
