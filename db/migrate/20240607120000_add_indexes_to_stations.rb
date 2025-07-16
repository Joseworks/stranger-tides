class AddIndexesToStations < ActiveRecord::Migration[7.0]
  def change
    add_index :stations, :station_name
    # Convert metadata from json to jsonb
    change_column :stations, :metadata, :jsonb, using: 'metadata::jsonb', default: {}, null: false
    add_index :stations, :metadata, using: :gin
  end
end 