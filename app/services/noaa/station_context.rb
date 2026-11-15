# frozen_string_literal: true

module Noaa
  class StationContext
    def initialize(station, units: 'english', client: nil)
      raise NoData, 'Choose US or metric units.' unless %w[english metric].include?(units)

      @station = station
      @units = units
      @client = client || Client.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20)
      @warnings = []
    end

    def call
      @now = Time.current.utc.change(sec: 0)
      discovery = ProductCatalog.new(client: @client)
      station = discovery.enrich([@station]).first
      @warnings << discovery.warning if discovery.warning
      datum = WaterLevelDatum.new(@station, client: @client).call
      { station_id: id, units: @units, datum:, fetched_at: @now.iso8601,
        one_minute: if station.fetch('additional_products', []).include?('one_minute_water_level')
                      optional('One-minute water levels') { one_minute(datum) }
                    else
                      []
                    end,
        forecast: station['forecast'] ? optional('Water-level forecast') { forecast(datum) } : [],
        flood_outlook: if station['outlook'] && datum == 'MLLW'
                         optional('Flood outlook') { flood_outlook }
                       else
                         []
                       end,
        products: optional('NOAA products') { products }, warnings: @warnings }
    end

    private

    def id = @station.fetch('station_id')

    def optional(name)
      yield
    rescue NoData, Unavailable => e
      @warnings << "#{name}: #{e.message}"
      []
    end

    def one_minute(datum)
      return [] unless datum

      payload = @client.get(StationReport::DATA_PATH,
                            { station: id, product: 'one_minute_water_level', datum:, units: @units,
                              time_zone: 'gmt', application: 'StrangerTides', format: 'json',
                              begin_date: (@now - 24.hours).strftime('%Y%m%d %H:%M'),
                              end_date: @now.strftime('%Y%m%d %H:%M') })
      Array(payload['data']).filter_map { |row| Series.observation(row, 'one_minute_water_level') }
    end

    def forecast(datum)
      return [] unless datum

      payload = @client.get(StationReport::DATA_PATH,
                            { station: id, product: 'ofs_water_level', datum:, units: @units,
                              time_zone: 'gmt', application: 'StrangerTides', format: 'json',
                              begin_date: @now.strftime('%Y%m%d %H:%M'),
                              end_date: (@now + 48.hours).strftime('%Y%m%d %H:%M') },
                            expires_in: 10.minutes)
      points = Array(payload['data']).filter_map do |row|
        Series.observation(row, 'ofs_water_level')
      end
      points.select { |point| Time.iso8601(point[:time]).between?(@now, @now + 48.hours) }
            .uniq { |point| point[:timestamp] }.sort_by { |point| point[:timestamp] }
    end

    # This endpoint explicitly accepts the requested datum. Raw MDAPI flood levels
    # do not declare a datum, so they must never be overlaid on an MLLW/IGLD chart.
    def flood_outlook
      payload = @client.get('/dpapi/prod/webapi/htb.json',
                            { station: id, date: @now.strftime('%Y%m%d'), range: 6,
                              datum: 'MLLW', units: @units }, expires_in: 6.hours)
      entries = Array(payload['floodLikelihood']).flat_map do |entry|
        entry.is_a?(Hash) ? Array(entry['NOS minor']) : []
      end
      rows = entries.filter_map { |row| flood_row(row) }
      rows.uniq { |row| row[:date] }.sort_by { |row| row[:date] }
    end

    def flood_row(row)
      return unless row.is_a?(Hash)

      date = Date.iso8601(row.fetch('date'))
      likelihood = Float(row['likelihood'], exception: false)
      threshold = Float(row['threshold'], exception: false)
      return unless date.between?(@now.to_date, @now.to_date + 6) &&
                    likelihood&.finite? && likelihood.between?(0, 100) && threshold&.finite?

      { date: date.iso8601, likelihood:, threshold:, updated: row['updated'].to_s }
    rescue KeyError, ArgumentError
      nil
    end

    def products
      payload = @client.get("/mdapi/prod/webapi/stations/#{id}/products.json", {},
                            expires_in: 1.day)
      Array(payload['products']).filter_map do |product|
        next unless product.is_a?(Hash)

        uri = URI.parse(product['value'].to_s)
        next unless %w[http https].include?(uri.scheme) && uri.userinfo.nil? &&
                    %w[tidesandcurrents.noaa.gov www.tidesandcurrents.noaa.gov].include?(uri.host)

        uri.scheme = 'https'
        { name: product['name'].to_s.first(150), url: uri.to_s }
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
