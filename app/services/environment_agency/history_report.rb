# frozen_string_literal: true

module EnvironmentAgency
  class HistoryReport
    def initialize(station, units: 'english', client: Client.new, **options)
      begin_date, end_date = options.values_at(:begin_date, :end_date)
      resolution = options.fetch(:resolution, 'auto')
      @first = parse(begin_date)
      @last = parse(end_date)
      today = Time.current.utc.to_date
      unless @first.between?(today - 27, @last) && @last <= today &&
             %w[auto fifteen_minute].include?(resolution)
        raise Noaa::NoData, 'UK history is available for the past 28 days at 15-minute resolution.'
      end

      @station = station
      @units = units
      @report = StationReport.new(station, units:, client:)
    end

    def call
      observations = @report.readings(@first.beginning_of_day.utc,
                                      [@last.end_of_day.utc, Time.current.utc].min)
      { station: @station, units: @units, datum: @station.fetch('datum'), observations:,
        predictions: [], differences: [], warnings: [], fetched_at: Time.current.utc.iso8601,
        source_name: 'Environment Agency', source_url: @station.fetch('source_url'),
        window: { begin_date: @first.iso8601, end_date: @last.iso8601,
                  resolution: 'fifteen_minute', product: 'water_level', interval_minutes: 15,
                  calendar_months: false } }
    end

    private

    def parse(value)
      raise ArgumentError unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

      Date.iso8601(value)
    rescue ArgumentError
      raise Noaa::NoData, 'Enter valid start and end dates (YYYY-MM-DD).'
    end
  end
end
