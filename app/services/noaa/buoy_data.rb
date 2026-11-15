# frozen_string_literal: true

module Noaa
  class BuoyData
    COLUMNS = { 'WVHT' => %w[wave_height m], 'DPD' => %w[wave_period s],
                'APD' => %w[average_period s], 'MWD' => ['wave_direction', '°'],
                'WSPD' => ['wind', 'm/s'], 'GST' => ['gust', 'm/s'],
                'WDIR' => ['wind_direction', '°'], 'WTMP' => ['water_temperature', '°C'],
                'ATMP' => ['air_temperature', '°C'], 'PRES' => %w[air_pressure hPa] }.freeze

    def initialize(units:, hours:)
      @units = units
      @hours = hours
    end

    def parse(body, now)
      lines = body.lines
      header = lines.shift.to_s.delete_prefix('#').split
      raise Unavailable, 'NOAA buoy columns are unreadable.' unless header.first(5) == %w[YY MM DD
                                                                                          hh mm]

      result = {}
      lines.each do |line|
        parsed = sample(line, header, now)
        next unless parsed

        time, values = parsed
        values.each do |product, value|
          (result[product] ||= []) << { time: time.iso8601, timestamp: time.to_i * 1000, value: }
        end
      end
      clean(result)
    end

    private

    def clean(result)
      result.reject! { |_, points| points.none? { |point| point[:value] } }
      result.transform_values do |points|
        points.uniq { |point| point[:timestamp] }.sort_by { |point| point[:timestamp] }
      end
    end

    def sample(line, header, now)
      return if line.start_with?('#')

      cells = line.split
      return if cells.length != header.length

      stamp = cells.first(5).join(' ')
      time = Time.strptime("#{stamp} +0000", '%Y %m %d %H %M %z')
      [time, measurements(cells, header)] if time.between?(now - @hours.hours, now)
    rescue ArgumentError
      nil
    end

    def measurements(cells, header)
      COLUMNS.filter_map do |column, (product, _)|
        index = header.index(column)
        value = Float(index && cells[index], exception: false)
        [product, value&.finite? ? convert(product, value) : nil] if index
      end.to_h
    end

    def convert(product, value)
      return value if @units == 'metric'
      return (value * 3.280839895).round(4) if product == 'wave_height'
      return (value * 1.943844492).round(4) if %w[wind gust].include?(product)
      return ((value * 9 / 5) + 32).round(4) if product.end_with?('temperature')

      value
    end
  end
end
