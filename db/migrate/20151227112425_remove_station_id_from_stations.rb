# frozen_string_literal: true

class RemoveStationIdFromStations < ActiveRecord::Migration[7.0]
  def change
    remove_column :stations, :station_id
  end
end
