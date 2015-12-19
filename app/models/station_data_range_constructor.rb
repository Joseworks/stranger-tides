class StationDataRangeConstructor
    include ActiveModel::Model
    validates :metadata, presence: true, numericality: { only_integer: true }

    attr_accessor :my_station,:product,:begin_date,:begin_time,:end_date,:end_time,:datum,:units,:time_zone,:application,:format,:url, :range_constructor
    def initialize(metadata)
      @range_constructor ={  my_station:  metadata,
                            product:  'water_level',
                            begin_date:  2.days.ago.strftime("%Y%m%d"),
                            begin_time:  2.days.ago.strftime('%R'),
                            end_date:  Time.now.strftime("%Y%m%d"),
                            end_time:  Time.now.strftime('%R'),
                            datum:  'mllw',
                            units: 'english',
                            time_zone: 'gmt',
                            application: 'web_services',
                            format: 'json'
                          }
    end
end
