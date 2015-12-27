class RemoveLatitudeFromStations < ActiveRecord::Migration
  def change
    remove_column :stations, :latitude
  end
end
