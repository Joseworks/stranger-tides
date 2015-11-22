include ActiveModel::Model

module GraphingService
  include ActiveModel::Serialization

  class ChartProcessor

    def self.grapher(station, tide_information, time_range)
        @chart = LazyHighCharts::HighChart.new('graph') do |f|
          f.title(:text => "Station name: #{station}")

          # this_tide = date_stripper(time_range)
          this_tide = date_converter(time_range)
          # p this_tide
          time_scale = (this_tide.last - this_tide.first).to_i
          p "  I AM THE TIME RANGE======#{time_range.first}   === #{time_range.last}  ===RANGE  #{(this_tide.last - this_tide.first).to_i}"
          # f.xAxis(:categories => this_tide)
          # this_tide = this_tide.each_slice(8).map(&:last)
          f.xAxis(:name => "Time",
                  :categories => this_tide,
                   tickInterval: time_scale * 24 * 3600 * 1000,
                   labels: {
                            align: 'left',
                            x: 30,
                            y: 0
                        }
                 )

          f.series(:name => "Height",
                   :yAxis => 0,
                   :data => tide_information
                   )
          # f.series(:name => "Population in Millions", :yAxis => 1, :data => [310, 127, 1340, 81, 65])
          f.yAxis [
            {:title => {:text => "Height in feet",
                                    :margin => 70}
                       }
            # {:title => {:text => "Population in Millions"}, :opposite => true},
                  ]

          f.legend( :align => 'right',
                    :verticalAlign => 'top',
                    :y => 75, :x => -50,
                    :layout => 'vertical'
                  )
          f.chart({:defaultSeriesType=>"line"})
        end
    end


    def self.date_converter(local_date)
      date_integers = []
      local_date.each do |d|
        date_integers << d.to_date
      end
      date_integers
    end

    def self.date_stripper(local_date)
      date_integers = []
      local_date.each do |d|
        date_integers << d.split(" ").last.split(":").join("").to_i
      end
      date_integers
    end

  end



end