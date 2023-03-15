# frozen_string_literal: true

namespace :stations_delete do
  desc 'Delete Station List'
  task delete_station_list: :environment do
    Station.delete_all
    p 'All stations have been erased'
  end
end
