# frozen_string_literal: true

module Noaa
  class CatalogPublisher
    def self.with_publication_lock
      Station.transaction do
        raise InvalidCatalog, 'Another catalog publication is running.' unless
          Station.connection.select_value('SELECT pg_try_advisory_xact_lock(60804221)')

        yield
      end
    end

    def self.restore(snapshot_id:)
      with_publication_lock do
        record = Station.find_by!(id: snapshot_id, station_name: Catalog::SNAPSHOT_NAME)
        Station.create!(station_name: record.station_name, metadata: record.metadata.deep_dup,
                        tide_info: record.tide_info)
      end
    end

    def initialize(rows, retrieved_at:, expected_snapshot_id:)
      @rows = rows
      @retrieved_at = retrieved_at
      @expected_snapshot_id = expected_snapshot_id
    end

    def call(apply:, allow_removals:)
      self.class.with_publication_lock do
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

    def validate_publication!(snapshot)
      # Snapshot IDs are publication generations, independent of NOAA data freshness.
      # A rollback creates a new ID even when it restores an older retrieved_at.
      raise InvalidCatalog, 'The catalog changed during discovery; retry the refresh.' if
        snapshot&.id != @expected_snapshot_id
      raise InvalidCatalog, 'A newer catalog was published while this refresh was running.' if
        snapshot && snapshot.metadata.fetch('retrieved_at') > @retrieved_at
    end

    def validate!(snapshot, previous, report, apply:, allow_removals:)
      validate_publication!(snapshot)
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
