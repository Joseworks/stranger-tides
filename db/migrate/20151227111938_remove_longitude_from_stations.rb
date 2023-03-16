# frozen_string_literal: true

class RemoveLongitudeFromStations < ActiveRecord::Migration[7.0]
  def change
    remove_column :stations, :longitude
  end
end
