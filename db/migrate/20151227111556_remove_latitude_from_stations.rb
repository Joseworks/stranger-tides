# frozen_string_literal: true

class RemoveLatitudeFromStations < ActiveRecord::Migration[4.2]
  def change
    remove_column :stations, :latitude
  end
end
