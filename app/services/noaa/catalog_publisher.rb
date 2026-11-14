# frozen_string_literal: true

module Noaa
  class CatalogPublisher
    def initialize(rows, retrieved_at:)
      @rows = rows
      @retrieved_at = retrieved_at
    end

    def call(apply:, allow_removals:)
      Station.transaction do
        lock!
        catalog = Catalog.new
        previous = catalog.stations
        report = differences(previous)
        validate!(catalog.snapshot, previous, report, apply:, allow_removals:)
        if apply
          Station.create!(station_name: Catalog::SNAPSHOT_NAME,
                          tide_info: @rows.pluck('station_id'),
                          metadata: { version: 1, retrieved_at: @retrieved_at, stations: @rows,
                                      sources: Catalog::TYPES, changes: report })
        end
        report.merge(applied: apply, count: @rows.length, retrieved_at: @retrieved_at)
      end
    end

    private

    def lock!
      return if Station.connection.select_value('SELECT pg_try_advisory_xact_lock(60804221)')

      raise InvalidCatalog, 'Another catalog refresh is running.'
    end

    def validate!(snapshot, previous, report, apply:, allow_removals:)
      raise InvalidCatalog, 'A newer catalog was published while this refresh was running.' if
        snapshot && snapshot.metadata.fetch('retrieved_at') > @retrieved_at
      raise InvalidCatalog, 'Review removed stations; retry with ALLOW_REMOVALS=1.' if
        apply && report[:removed].any? && !allow_removals

      counts = ->(rows) { rows.flat_map { |s| s.fetch('capabilities', ['waterlevels']) }.tally }
      before = counts.call(previous)
      after = counts.call(@rows)
      before.each do |type, count|
        raise InvalidCatalog, "The #{type} catalog unexpectedly shrank by more than 10%." if
          after.fetch(type, 0) < count * 0.9
      end
    end

    def differences(previous)
      old = previous.index_by { |station| station['station_id'] }
      fresh = @rows.index_by { |station| station['station_id'] }
      { added: fresh.keys - old.keys, removed: old.keys - fresh.keys,
        changed: (old.keys & fresh.keys).reject { |id| old[id] == fresh[id] } }
    end
  end
end
