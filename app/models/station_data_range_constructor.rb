# frozen_string_literal: true

# class StationDataRangeConstructor < ApplicationRecord
# In the future this StationDataRangeConstructor will receive a custom
# date range to form requests. Right now it just acts similarly to a Value Object.

class StationDataRangeConstructor
  include ActiveModel::Model
  validates :my_station, presence: true, numericality: { only_integer: true }

  def initialize(station_id, datum)
    @range_constructor =
      {
        my_station: station_id,
        product: 'water_level',
        begin_date: 2.days.ago.strftime('%Y%m%d'),
        begin_time: 2.days.ago.strftime('%R'),
        end_date: Time.zone.now.strftime('%Y%m%d'),
        end_time: Time.zone.now.strftime('%R'),
        datum: datum,
        units: 'english',
        time_zone: 'gmt',
        application: 'NOS.COOPS.TAC.WL',
        format: 'json'
      }
  end

  attr_accessor :my_station,
                :product,
                :begin_date,
                :begin_time,
                :end_date,
                :end_time,
                :datum,
                :units,
                :time_zone,
                :application,
                :format,
                :url,
                :range_constructor,
                :datum
end
