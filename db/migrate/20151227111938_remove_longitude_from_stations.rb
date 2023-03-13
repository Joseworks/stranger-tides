class RemoveLongitudeFromStations < ActiveRecord::Migration[4.2]
  def change
    remove_column :stations, :longitude
  end
end
