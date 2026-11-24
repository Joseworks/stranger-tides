# frozen_string_literal: true

module Noaa
  class StationContext
    def initialize(station, units: 'english', client: nil)
      raise NoData, 'Choose US or metric units.' unless %w[english metric].include?(units)

      @station = station
      @units = units
      @client = client || Client.new(deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20)
      @warnings = []
      @failed_products = []
    end

    def call
      @now = Time.current.utc.change(sec: 0)
      station = discover
      datum = height_reference
      { station_id: id, units: @units, datum:, fetched_at: @now.iso8601,
        one_minute: if station.fetch('additional_products', []).include?('one_minute_water_level')
                      optional('One-minute water levels', product: 'one_minute') do
                        one_minute(datum)
                      end
                    else
                      []
                    end,
        forecast: if station['forecast']
                    optional('Water-level forecast', product: 'forecast') do
                      forecast(datum)
                    end
                  else
                    []
                  end,
        flood_outlook: if station['outlook'] && datum == 'MLLW'
                         optional('Flood outlook', product: 'flood_outlook') { flood_outlook }
                       else
                         []
                       end,
        products: optional('NOAA products', product: 'products') do
          products
        end, warnings: @warnings, failed_products: @failed_products.uniq }
    end

    private

    def id = @station.fetch('station_id')

    def discover
      discovery = ProductCatalog.new(client: @client)
      station = discovery.enrich([@station]).first
      @warnings << discovery.warning if discovery.warning
      @failed_products.push('forecast', 'flood_outlook') if
        discovery.failed_sources.include?('station_products')
      @failed_products << 'one_minute' if discovery.failed_sources.include?('one_minute')
      station
    end

    def height_reference
      WaterLevelDatum.new(@station, client: @client).call
    rescue NoData, Unavailable => e
      if e.is_a?(Unavailable)
        @failed_products.push('datum', 'one_minute', 'forecast', 'flood_outlook')
      end
      @warnings << "Height reference: #{e.message}"
      nil
    end

    def optional(name, product:)
      yield
    rescue NoData, Unavailable => e
      @failed_products << product if e.is_a?(Unavailable)
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
      rows = entries.filter_map { |row| Series.flood_outlook_row(row, now: @now) }
      rows.uniq { |row| row[:date] }.sort_by { |row| row[:date] }
    end

    def products
      ProductCatalog.links(@client.get("/mdapi/prod/webapi/stations/#{id}/products.json", {},
                                       expires_in: 1.day)['products'])
    end
  end
end
