# frozen_string_literal: true

# Creates the graph through a HighChart instance.
include ActionView::Helpers::DateHelper
module GraphingService
  class ChartProcessor
    def self.grapher(station, tide_information, time_range)
      @chart = LazyHighCharts::HighChart.new('graph') do |f|
        this_tide = date_converter(time_range)

        time_scale = (this_tide.last.to_date - this_tide.first.to_date).to_i
        distance = distance_of_time_in_words(this_tide.last, this_tide.first)

        f.title(text: "Station name: #{station}, Time range #{distance}")
        f.subtitle(text: 'Source: NOAA CO-OPS API')

        f.xAxis(name: 'Time',
                type: 'datetime',
                categories: this_tide,
                tickInterval: time_scale * 30,
                tickWidth: 1,
                gridLineWidth: 1,
                labels: {
                  align: 'right',
                  x: 0,
                  y: 0
                })

        f.series(name: 'Height', yAxis: 0, data: tide_information)

        f.yAxis [{ title: { text: 'Height in feet', margin: 70 } }]

        f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical')
        f.chart(defaultSeriesType: 'line')
      end
    end

    def self.date_converter(local_date)
      converted_date = []

      local_date.each_with_index do |d, index|
        converted_date << if index.zero? || index == local_date.length - 1
                            d.split.first
                          else
                            "#{d.split.last} hrs"
                          end
      end

      converted_date
    end
  end
end
