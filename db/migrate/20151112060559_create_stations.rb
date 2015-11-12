class CreateStations < ActiveRecord::Migration
  def change
    create_table :stations do |t|
      t.integer :station_id
      t.string :station_name
      t.float :latitude
      t.float :longitude
      t.text :tide_info, array: true, default: []

      t.timestamps null: false
    end
  end
end
