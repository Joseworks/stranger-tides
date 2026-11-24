# frozen_string_literal: true

module Noaa
  class Series
    def self.flood_outlook_row(row, now:)
      return unless row.is_a?(Hash)

      return unless row['date'].is_a?(String)

      date = Date.iso8601(row['date'])
      likelihood = Float(row['likelihood'], exception: false)
      threshold = Float(row['threshold'], exception: false)
      return unless date.between?(now.to_date, now.to_date + 6) &&
                    likelihood&.finite? && likelihood.between?(0, 100) && threshold&.finite?

      { date: date.iso8601, likelihood:, threshold:, updated: row['updated'].to_s }
    rescue KeyError, ArgumentError
      nil
    end

    def self.specific_gravity(points)
      points.map do |point|
        point.merge(value: point[:specific_gravity]&.finite? ? point[:specific_gravity] : nil)
      end
    end

    def self.latest(series)
      series.transform_values { |points| points.rfind { |point| point[:value] } }.compact
    end

    def self.observation(row, product)
      return unless row.is_a?(Hash)

      time = Time.strptime("#{row.fetch('t')} +0000", '%Y-%m-%d %H:%M %z')
      value = Float(row[%w[wind salinity].include?(product) ? 's' : 'v'], exception: false)
      gravity = product == 'salinity' ? Float(row['g'], exception: false) : nil
      { timestamp: (time.to_f * 1000).to_i, time: time.iso8601,
        value: value&.finite? ? value : nil, quality: row['q'], flags: row['f'],
        type: row['type'], direction: row['d'], gust: row['g'],
        specific_gravity: gravity&.finite? ? gravity : nil }
    rescue KeyError, ArgumentError
      nil
    end

    # Only exact timestamps in the same datum/units are comparable. Never interpolate
    # subordinate high/low events, missing readings or suspect flagged observations.
    def self.differences(observed, predicted, subordinate: false)
      return [] if subordinate || predicted.empty?

      index = predicted.index_by { |point| point[:timestamp] }
      observed.map do |point|
        prediction = index[point[:timestamp]]
        valid = point[:value] && prediction&.dig(:value) && point[:flags].to_s.split(',').all?('0')
        point.merge(value: valid ? (point[:value] - prediction[:value]).round(6) : nil)
      end
    end
  end
end
