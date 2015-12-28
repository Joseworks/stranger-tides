namespace :stations_delete do
  require 'open-uri'
  desc "Delete Station List"
    task :delete_station_list => :environment do
      Station.delete_all
      p "All stations have been erased"
    end
end
