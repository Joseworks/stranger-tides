FactoryGirl.define do
  factory :station do
    # skip_create
    my_station = 8723214
    product = 'water_level'
    begin_date = 1.days.ago.strftime("%Y%m%d")
    begin_time = 1.days.ago.strftime('%R')
    end_date = Time.zone.now.strftime("%Y%m%d")
    end_time = Time.zone.now.strftime('%R')
    datum = 'mllw'
    units='english'
    time_zone='gmt'
    application='web_services'
    format='json'
  end
end
