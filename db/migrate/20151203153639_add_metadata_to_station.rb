# frozen_string_literal: true

class AddMetadataToStation < ActiveRecord::Migration[4.2]
  def change
    add_column :stations, :metadata, :json, default: {}, null: false
  end
end
