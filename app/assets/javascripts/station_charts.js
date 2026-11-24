/* global Highcharts */
(() => {
  'use strict';
  window.StationCharts = {
    update(chart, options, preserveView = false) {
      if (!preserveView) {chart.update(options, true, true, false); return;}
      const axes = ['xAxis', 'yAxis'].flatMap(kind => chart[kind].map((axis, index) => {
        const {userMin, userMax} = axis.getExtremes();
        return {kind, index, id: axis.options.id, userMin, userMax};
      }));
      const visibility = new Map(chart.series.map(series => [series.options.id || series.name, series.visible]));
      chart.update(options, false, true, false);
      axes.forEach(({kind, index, id, userMin, userMax}) => {
        const axis = id ? chart[kind].find(a => a.options.id === id) : chart[kind][index];
        if (axis && (Number.isFinite(userMin) || Number.isFinite(userMax))) axis.setExtremes(userMin, userMax, false, false);
      });
      chart.series.forEach(series => {
        const visible = visibility.get(series.options.id || series.name);
        if (visible !== undefined) series.setVisible(visible, false);
      });
      chart.redraw(false);
    }
  };
})();
