class RemoveLongitudeFromStations < ActiveRecord::Migration
  def change
    remove_column :stations, :longitude
  end
end
