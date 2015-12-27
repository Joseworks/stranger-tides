class RemoveStationIdFromStations < ActiveRecord::Migration
  def change
    remove_column :stations, :station_id
  end
end
