# frozen_string_literal: true

class AddMetadataToStation < ActiveRecord::Migration[7.0]
  def change
    add_column :stations, :metadata, :json, default: {}, null: false
  end
end
