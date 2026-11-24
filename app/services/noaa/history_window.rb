# frozen_string_literal: true

module Noaa
  class HistoryWindow
    PRODUCTS = { 'six_minute' => 'water_level', 'hourly' => 'hourly_height',
                 'monthly' => 'monthly_mean' }.freeze
    attr_reader :first, :last, :resolution

    def initialize(begin_date:, end_date:, resolution: 'auto')
      @first = parse(begin_date)
      @last = parse(end_date)
      validate_dates!

      days = (@last - @first).to_i + 1
      @resolution = resolution == 'auto' ? automatic(days) : resolution
      raise NoData, 'Use six-minute data for up to 30 days, hourly for 365 days, or monthly.' unless
        PRODUCTS.key?(@resolution) && (@resolution != 'six_minute' || days <= 30) &&
        (@resolution != 'hourly' || days <= 365)
    end

    def product = PRODUCTS.fetch(resolution)

    def monthly? = resolution == 'monthly'

    def parameters
      { begin_date: (monthly? ? first.beginning_of_month : first).strftime('%Y%m%d'),
        end_date: (monthly? ? last.end_of_month : last).strftime('%Y%m%d') }
    end

    def include?(point)
      date = Date.iso8601(point.fetch(:time))
      bounds = monthly? ? [first.beginning_of_month, last.end_of_month] : [first, last]
      date.between?(*bounds)
    end

    def metadata
      { begin_date: first.iso8601, end_date: last.iso8601, resolution:, product:,
        interval_minutes: { 'six_minute' => 6, 'hourly' => 60 }[resolution],
        calendar_months: monthly? }
    end

    private

    def validate_dates!
      months = ((last.year - first.year) * 12) + last.month - first.month
      return if first.between?(Date.new(1800), last) && last <= Time.current.utc.to_date &&
                months < 2400

      raise NoData, 'Choose ordered dates from 1800 through today, within 200 years.'
    end

    def parse(value)
      raise ArgumentError unless value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)

      Date.iso8601(value)
    rescue ArgumentError
      raise NoData, 'Enter valid start and end dates (YYYY-MM-DD).'
    end

    def automatic(days)
      return 'six_minute' if days <= 30

      days <= 365 ? 'hourly' : 'monthly'
    end
  end
end
