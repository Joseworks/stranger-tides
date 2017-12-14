class AddMetadataToStation < ActiveRecord::Migration
  def change
    add_column :stations, :metadata, :json, default: {}, null: false
  end
end
