# frozen_string_literal: true

FactoryBot.define do
  factory :station do
    my_station { 8_723_214 }
    product { 'water_level' }
    begin_date  { 1.day.ago.strftime('%Y%m%d') }
    begin_time  { 1.day.ago.strftime('%R') }
    end_date  { Time.zone.now.strftime('%Y%m%d') }
    end_time  { Time.zone.now.strftime('%R') }
    datum  { 'mllw' }
    units  { 'english' }
    time_zone { 'gmt' }
    application { 'web_services' }
    format { 'json' }
    station_name { 'USS Lexington' }
  end
end
