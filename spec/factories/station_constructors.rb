FactoryGirl.define do
  factory :station_constructor do
    before(:create) do
      station = FactoryGirl.create(:station)
      p station.inspect
      constructed_station_params ={ my_station: my_station,
                                    product: product,
                                    begin_date: begin_date,
                                    begin_time: begin_time,
                                    end_date: end_date,
                                    end_time: end_time,
                                    datum: datum,
                                    units: units,
                                    time_zone: time_zone,
                                    application: application,
                                    format: format
                                  }
    end
  end
end
