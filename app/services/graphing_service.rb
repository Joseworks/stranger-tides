include ActiveModel::Model

module GraphingService

  class ChartProcessor

    def self.grapher(station, tide_information, time_range)
        @chart = LazyHighCharts::HighChart.new('graph') do |f|
          f.title(:text => "Station name: #{station}")




          this_tide = date_stripper(time_range)
          p this_tide

          f.xAxis(:categories => ["United States", "Japan", "China", "Germany", "France"])
          f.xAxis(:categories => this_tide)
          # f.series(:name => "GDP in Billions", :yAxis => 0, :data => [14119, 5068, 4985, 3339, 2656])
          f.series(:name => "Height", :yAxis => 0, :data => tide_information)
          # f.series(:name => "Population in Millions", :yAxis => 1, :data => [310, 127, 1340, 81, 65])
          f.yAxis [
            {:title => {:text => "Height", :margin => 70} }
            # {:title => {:text => "Population in Millions"}, :opposite => true},
          ]

          f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
          f.chart({:defaultSeriesType=>"line"})
        end
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