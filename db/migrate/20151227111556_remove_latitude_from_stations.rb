# frozen_string_literal: true

class RemoveLatitudeFromStations < ActiveRecord::Migration[7.0]
  def change
    remove_column :stations, :latitude
  end
end
