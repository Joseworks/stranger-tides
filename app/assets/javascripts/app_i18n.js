/* global Highcharts */
(() => {
  'use strict';
  const payload = JSON.parse(document.getElementById('app-i18n').textContent);
  const locale = payload.locale, messages = payload.messages;
  const number = (value, digits = 2) => new Intl.NumberFormat(locale, {
    minimumFractionDigits: digits, maximumFractionDigits: digits
  }).format(value);
  function t(source, ...values) {
    if (typeof source !== 'string' && !Array.isArray(source)) return String(source ?? '');
    const key = typeof source === 'string' ? source : source.map((part, i) => part + (i < values.length ? `{${i}}` : '')).join('');
    const phrase = Object.hasOwn(messages, key) ? messages[key] : key;
    return phrase.replace(/\{(\d+)\}/g, (match, index) => index < values.length ? String(values[index]) : match);
  }
  window.AppI18n = {locale, t, number};
  document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('language-select')?.addEventListener('change', event => {
      const url = new URL(location.href); url.searchParams.set('locale', event.target.value);
      location.assign(url.href);
    });
    if (window.Highcharts) {
      const month = style => Array.from({length:12}, (_,i) => new Intl.DateTimeFormat(locale,{month:style,timeZone:'UTC'}).format(new Date(Date.UTC(2020,i,1))));
      const weekdays = Array.from({length:7}, (_,i) => new Intl.DateTimeFormat(locale,{weekday:'long',timeZone:'UTC'}).format(new Date(Date.UTC(2020,0,5+i))));
      const parts = new Intl.NumberFormat(locale).formatToParts(1234.5);
      Highcharts.setOptions({lang:{locale, months:month('long'),shortMonths:month('short'),weekdays,
        decimalPoint:parts.find(p=>p.type==='decimal')?.value || '.',thousandsSep:parts.find(p=>p.type==='group')?.value || ',',
        resetZoom:t('Reset zoom'),resetZoomTitle:t('Reset zoom level 1:1'),loading:t('Loading…'),
        downloadPNG:t('Download PNG image'),downloadJPEG:t('Download JPEG image'),downloadPDF:t('Download PDF document'),downloadSVG:t('Download SVG vector image'),
        viewFullscreen:t('View in full screen'),exitFullscreen:t('Exit from full screen'),printChart:t('Print chart')}});
    }
  });
})();
