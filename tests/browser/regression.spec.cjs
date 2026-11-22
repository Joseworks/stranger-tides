const { test, expect } = require('@playwright/test');
const path = require('node:path');
const station = (page, id) => page.locator(`#station-results button[data-station-id="${id}"]`);
const chart = page => page.locator('#graph-partial .highcharts-title');

test.beforeEach(async ({ page }) => {
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.route('https://maps.googleapis.com/**', route => route.fulfill({
    path: path.join(__dirname, 'maps-fixture.js'), contentType: 'application/javascript'
  }));
  page.testErrors = errors;
});
test.afterEach(async ({ page }) => expect(page.testErrors).toEqual([]));

test('search, layers, and fingerprinted markers expose the complete catalog', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#result-count')).toHaveText('2 matching locations');
  await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible();
  await expect(page.locator('#full_map img').first()).toHaveJSProperty('naturalWidth', 32);
  await page.getByLabel('Find a station', { exact: true }).fill('MN');
  await expect(station(page, '9099064')).toBeVisible();
  await expect(station(page, '9414290')).toHaveCount(0);
  await page.getByLabel('Find a station', { exact: true }).fill('');
  await page.getByLabel('Show stations', { exact: true }).selectOption('tidepredictions');
  await expect(station(page, 'TWC0331')).toBeVisible();
});

for (const advanced of [false, true]) {
  test(`individual ${advanced ? 'advanced' : 'legacy'} pins spread radially and select without zooming`, async ({page}) => {
    if (advanced) await page.addInitScript(() => {window.useAdvancedMarkersFixture=true;});
    await page.goto('/'); await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
    await expect(page.locator('.map-legend')).toContainText('Each pin is one station');
    await page.evaluate(() => fixtureMap.setZoom(0));
    const pin=page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true});
    await expect(pin).toBeVisible();
    await expect(page.locator('#full_map').getByRole('button',{name:'Duluth, MN 9099064',exact:true})).toBeVisible();
    const before=await page.locator('#full_map').getAttribute('data-center');
    await pin.click();
    const picker=page.getByRole('dialog',{name:'Choose an overlapping station'});
    await expect(picker).toBeVisible(); await expect(picker.locator('.spread-station')).toHaveCount(2);
    await expect(picker.locator('line')).toHaveCount(2);
    await picker.getByRole('button',{name:'Duluth, MN 9099064',exact:true}).click();
    await expect(chart(page)).toHaveText('Duluth, MN'); await expect(picker).toHaveCount(0);
    await expect(page.locator('#full_map')).toHaveAttribute('data-zoom','0');
    await expect(page.locator('#full_map')).toHaveAttribute('data-center',before);
  });
}

test('shared selections position the map after a delayed SDK, and ordinary pans retain markers', async ({ page }) => {
  let release; const barrier = new Promise(resolve => { release = resolve; });
  await page.route('https://maps.googleapis.com/**', async route => {
    await barrier; await route.fulfill({ path: path.join(__dirname, 'maps-fixture.js'), contentType: 'application/javascript' });
  });
  await page.goto('/?station=9099064'); await expect(chart(page)).toHaveText('Duluth, MN');
  release(); await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible();
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom', '8');
  await expect(page.locator('#full_map')).toHaveAttribute('data-center', JSON.stringify({ lat: 46.775, lng: -92.092 }));
  await expect(page.getByRole('dialog')).toContainText('Duluth, MN');
  const marker = await page.locator('#full_map button').first().elementHandle();
  await page.evaluate(() => fixtureMap.setCenter({ lat: 47, lng: -93 }));
  expect(await marker.evaluate(node => node.isConnected)).toBe(true);
});

test('reading age and stale warning advance without replacing charts', async ({ page }) => {
  await page.clock.install();
  await page.goto('/'); await station(page, '9414290').click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
  const index = await page.evaluate(() => chart_graph_partial.index);
  await expect(page.locator('#reading-freshness')).toBeHidden();
  await page.clock.fastForward(30 * 60000);
  await expect(page.locator('#reading-age')).toContainText(/3\d minutes ago/);
  await expect(page.locator('#reading-freshness')).toContainText('observation is now stale');
  await page.clock.fastForward(2 * 60 * 60000);
  await expect(page.locator('#next-events')).not.toContainText('Next predicted high');
  await expect(page.locator('#next-events')).toContainText('Next predicted low');
  await page.clock.fastForward(6 * 60 * 60000);
  await expect(page.locator('#next-events')).toContainText('Upcoming predictions have passed');
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(index);
});

test('selection keeps keyboard focus visible without forcing a scroll to off-screen details', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 350 });
  await page.goto('/'); await station(page, '9414290').scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => scrollY);
  await station(page, '9414290').click(); await expect(chart(page)).toHaveText('San Francisco, CA');
  const focus = await page.evaluate(() => {const r = document.activeElement.getBoundingClientRect(); return {top: r.top, bottom: r.bottom, height: innerHeight};});
  expect(focus.top).toBeGreaterThanOrEqual(0); expect(focus.bottom).toBeLessThanOrEqual(focus.height);
  expect(Math.abs(await page.evaluate(() => scrollY) - before)).toBeLessThan(2);
});

test('real chart preserves gaps, shows predictions and quality, and switches units and time', async ({ page }) => {
  await page.goto('/'); await station(page, '9414290').click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
  expect(await page.evaluate(() => chart_graph_partial.series[0].getColumn('y'))).toEqual([0.12, null, 0.18]);
  await expect(page.locator('#station-summary')).toContainText('Preliminary');
  await expect(page.locator('#station-summary')).toContainText('Next predicted high');
  await expect(page.locator('#station-summary')).toContainText('air pressure:');
  await expect(page.locator('#station-summary')).toContainText('humidity:');
  await expect(page.locator('#station-summary')).toContainText('Water Temperature: sensor disabled · Under review');
  expect(await page.evaluate(() => chart_graph_partial.series.map(s => s.name))).toEqual(['Observed water level', 'Predicted water level']);
  await page.getByLabel('Units', { exact: true }).selectOption('metric');
  await expect(page.locator('.latest-reading')).toContainText('0.05 m above MLLW');
  await page.getByLabel('Time', { exact: true }).selectOption('utc');
  await expect(page.locator('#station-summary')).toContainText('Times: UTC');
  await page.getByText('View measurements as a table', { exact: true }).click();
  await expect(page.locator('#measurement-rows')).toContainText('Missing');
  expect(await page.evaluate(() => chart_graph_partial.xAxis[0].categories)).toBeFalsy();
});

test('Great Lakes chart uses IGLD and closes with focus restored', async ({ page }) => {
  await page.goto('/'); await station(page, '9099064').click();
  await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('.latest-reading')).toContainText('602.18 ft above IGLD');
  await expect(page.locator('#station-heading')).toHaveText('Duluth, MN 9099064');
  await expect(station(page, '9099064')).toContainText('Duluth, MN');
  await expect(page.locator('.datum-explanation')).toContainText('rather than tide height');
  await expect(page.locator('#station-summary')).toContainText('Variation 0.06 ft');
  expect(await page.evaluate(() => chart_graph_partial.yAxis[0].axisTitle.textStr)).toBe('Lake-level elevation (ft, IGLD)');
  await page.getByRole('button', { name: 'Close station details', exact: true }).click();
  await expect(page.locator('#station-panel')).toBeHidden();
  await expect(station(page, '9099064')).toBeFocused();
});

test('omitted observation rows break the line across a six-hour outage', async ({ page }) => {
  let firstTimestamp;
  await page.route('**/stations/9414290/report?*', async route => {
    const response = await route.fetch(); const payload = await response.json();
    const last = payload.observations.at(-1);
    firstTimestamp = last.timestamp - 6 * 60 * 60000;
    payload.observations = [{ ...payload.observations[0], timestamp: firstTimestamp,
      time: new Date(firstTimestamp).toISOString() }, last];
    await route.fulfill({ response, json: payload });
  });
  await page.goto('/'); await station(page, '9414290').click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
  expect(await page.evaluate(() => chart_graph_partial.series[0].getColumn('y'))).toEqual([0.12, null, 0.18]);
  expect(await page.evaluate(() => chart_graph_partial.series[0].getColumn('x')))
    .toEqual([firstTimestamp, firstTimestamp + 6 * 60000, firstTimestamp + 6 * 60 * 60000]);
  expect(await page.evaluate(() => chart_graph_partial.series[0].options.connectNulls)).toBe(false);
});

test('NOAA link follows selection immediately and survives the new station failing', async ({ page }) => {
  let release; const barrier = new Promise(resolve => { release = resolve; });
  await page.route('**/stations/9099064/report?*', async route => {
    await barrier; await route.fulfill({ status: 503, json: { error: 'Station unavailable' } });
  });
  await page.goto('/'); await station(page, '9414290').click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
  await expect(page.locator('#noaa-station-link')).toHaveAttribute('href', /id=9414290$/);
  await station(page, '9099064').click();
  await expect(page.locator('#report-status')).toContainText('Loading NOAA');
  await expect(page.locator('#noaa-station-link')).toHaveAttribute('href', /id=9099064$/);
  release();
  await expect(page.locator('#report-status')).toContainText('Station unavailable');
  await expect(page.locator('#noaa-station-link')).toHaveAttribute('href', /id=9099064$/);
});

test('replacing a station leaves one current chart and shareable URL', async ({ page }) => {
  await page.goto('/'); await station(page, '9414290').click(); await expect(chart(page)).toHaveText('San Francisco, CA');
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('#graph-partial .highcharts-container')).toHaveCount(1);
  await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
  await expect(page).toHaveURL(/station=9099064/);
  await page.reload(); await expect(chart(page)).toHaveText('Duluth, MN');
});

test('closing during a delayed request prevents its response from reopening details', async ({ page }) => {
  let release; const barrier = new Promise(resolve => { release = resolve; });
  await page.route('**/stations/9414290/report?*', async route => {
    await barrier; await route.fulfill({ status: 503, json: { error: 'Late response' } }).catch(() => {});
  });
  await page.goto('/'); await station(page, '9414290').click();
  await page.getByRole('button', { name: 'Close station details', exact: true }).click(); release();
  await expect(page.locator('#station-panel')).toBeHidden();
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
});

test('an obsolete slow response cannot replace the newer selection', async ({ page }) => {
  let release; const barrier = new Promise(resolve => { release = resolve; });
  await page.route('**/stations/9414290/report?*', async route => {
    await barrier; await route.fulfill({ status: 503, json: { error: 'Old station failed' } }).catch(() => {});
  });
  await page.goto('/'); await station(page, '9414290').click(); await station(page, '9099064').click();
  await expect(chart(page)).toHaveText('Duluth, MN'); release();
  await expect(page.locator('#report-status')).not.toContainText('Old station failed');
});

test('NOAA outage offers a usable retry', async ({ page }) => {
  let fail = true;
  await page.route('**/stations/9414290/report?*', route => fail ? route.fulfill({ status: 503, json: { error: 'NOAA is temporarily unavailable.' } }) : route.continue());
  await page.goto('/'); await station(page, '9414290').click();
  await expect(page.locator('#report-status')).toContainText('temporarily unavailable');
  await expect(page.locator('#noaa-station-link')).toHaveAttribute('href', /id=9414290$/);
  fail = false; await page.getByRole('button', { name: 'Retry station data' }).click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
});

test('prediction-only locations render without pretending to have live observations', async ({ page }) => {
  await page.goto('/'); await page.getByLabel('Show stations', { exact: true }).selectOption('tidepredictions');
  await station(page, 'TWC0331').click(); await expect(chart(page)).toHaveText('Prediction Harbor, CA');
  await expect(page.locator('.latest-reading')).toHaveText('No water-level observation available.');
  expect(await page.evaluate(() => chart_graph_partial.series.map(s => s.name))).toEqual(['Predicted high/low events']);
  expect(await page.evaluate(() => chart_graph_partial.series[0].type)).toBe('scatter');
  await expect(page.locator('#weather-charts')).toBeHidden();
  await page.getByText('View measurements as a table', { exact: true }).click();
  await expect(page.locator('#measurement-rows')).toContainText('Predicted water level');
  await expect(page.locator('#measurement-rows')).toContainText('High');
});

test('every enabled weather product has history, while disabled sensors have no graph', async ({ page }) => {
  await page.goto('/');
  for (const id of ['9414290', '9099064']) {
    await station(page, id).click();
    await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
    for (const product of ['wind', 'air_temperature', 'air_pressure', 'humidity']) {
      await expect(page.locator(`#weather-${product} .highcharts-container`)).toBeVisible();
    }
    await expect(page.locator('#weather-water_temperature')).toHaveCount(0);
    const wind = await page.evaluate(() => {
      const c = Highcharts.charts.find(c => c?.renderTo.id === 'weather-wind');
      return { names: c.series.map(s => s.name), gusts: c.series[1].getColumn('y'),
        direction: c.series[2].getColumn('y'), directionType: c.series[2].type };
    });
    expect(wind).toEqual({ names: ['Wind speed', 'Wind gust', 'Wind direction'],
      gusts: [14, null, 14], direction: [180, 180], directionType: 'scatter' });
  }
});

test('wind gusts and direction remain graphed when sustained speed is missing', async ({ page }) => {
  await page.route('**/stations/9414290/report?*', async route => {
    const response = await route.fetch(); const payload = await response.json();
    payload.weather_series.wind.forEach(point => { point.value = null; });
    delete payload.weather.wind;
    await route.fulfill({ response, json: payload });
  });
  await page.goto('/'); await station(page, '9414290').click();
  await expect(page.locator('#weather-wind .highcharts-container')).toBeVisible();
  expect(await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'weather-wind').series[1].getColumn('y')))
    .toEqual([14, null, 14]);
});

test('history, units, and time update existing charts without navigation or scrolling', async ({ page }) => {
  let hold = false, release; const barrier = new Promise(resolve => { release = resolve; });
  let reports = 0, navigations = 0;
  page.on('request', request => { if (request.isNavigationRequest() && request.frame() === page.mainFrame()) navigations++; });
  await page.route('**/stations/9414290/report?*', async route => {
    reports++; if (hold) await barrier; await route.continue();
  });
  await page.goto('/'); await station(page, '9414290').click();
  await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
  await page.locator('#history-hours').scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => ({ y: scrollY, water: chart_graph_partial.index,
    wind: Highcharts.charts.find(c => c?.renderTo.id === 'weather-wind').index,
    height: document.getElementById('station-charts').offsetHeight }));
  const initialNavigations = navigations;
  hold = true;
  await page.getByLabel('History', { exact: true }).selectOption('72');
  await expect(page.locator('#report-status')).toContainText('Updating station charts');
  expect(await page.evaluate(() => document.getElementById('station-charts').offsetHeight)).toBe(before.height);
  expect(Math.abs(await page.evaluate(() => scrollY) - before.y)).toBeLessThan(2);
  release(); hold = false;
  await expect(page.locator('#graph-partial .highcharts-subtitle')).toContainText('Past 72 hours');
  await expect(page.locator('#weather-wind .highcharts-subtitle')).toContainText('Past 72 hours');
  await page.getByLabel('Units', { exact: true }).selectOption('metric');
  await expect(page.locator('#weather-air_temperature')).toContainText('°C');
  await expect(page.locator('#weather-wind')).toContainText('m/s');
  const previousReports = reports;
  await page.getByLabel('Time', { exact: true }).selectOption('utc');
  expect(await page.evaluate(() => chart_graph_partial.options.time.timezone)).toBe('UTC');
  expect(await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'weather-wind').options.time.timezone)).toBe('UTC');
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(before.water);
  expect(await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'weather-wind').index)).toBe(before.wind);
  expect(Math.abs(await page.evaluate(() => scrollY) - before.y)).toBeLessThan(2);
  expect(navigations).toBe(initialNavigations); expect(reports).toBe(previousReports);
});

test('station local time updates all charts and shared links without fetching or scrolling', async ({ page }) => {
  let reports = 0;
  page.on('request', request => { if (request.url().includes('/report?')) reports++; });
  await page.goto('/?station=9414290&zone=station');
  await expect(chart(page)).toHaveText('San Francisco, CA');
  await expect(page.locator('#station-summary')).toContainText('Times: America/Los_Angeles');
  await expect(page.locator('#catalog-status')).toContainText(' UTC');
  const catalog = await page.locator('#catalog-status').innerText();
  await page.getByLabel('Time', { exact: true }).scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => ({ y: scrollY, water: chart_graph_partial.index }));
  const count = reports;
  await page.getByLabel('Time', { exact: true }).selectOption('utc');
  await page.getByLabel('Time', { exact: true }).selectOption('station');
  const zones = await page.evaluate(() => Highcharts.charts.filter(Boolean).map(c => c.options.time.timezone));
  expect(zones.length).toBeGreaterThanOrEqual(5); expect(zones.every(z => z === 'America/Los_Angeles')).toBe(true);
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(before.water);
  expect(Math.abs(await page.evaluate(() => scrollY) - before.y)).toBeLessThan(2);
  expect(reports).toBe(count); await expect(page).toHaveURL(/zone=station/);
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('#station-summary')).toContainText('Times: America/Chicago');
  await expect(page.locator('#catalog-status')).toHaveText(catalog);
});

test('missing station time-zone metadata is explicit and does not break shared reports', async ({ page }) => {
  await page.route('**/stations/9414290/report?*', async route => {
    const response = await route.fetch(); const payload = await response.json();
    payload.station_timezone = null; await route.fulfill({ response, json: payload });
  });
  await page.goto('/?station=9414290&zone=station'); await expect(chart(page)).toHaveText('San Francisco, CA');
  await expect(page.locator('#display-zone option[value="station"]')).toBeDisabled();
  await expect(page.locator('#display-zone option[value="station"]')).toHaveText('Station local time unavailable (UTC)');
  await expect(page.locator('#station-summary')).toContainText('Times: UTC');
  await page.getByLabel('Time', { exact: true }).selectOption('local');
  await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
});

test('a failed history refresh preserves the existing graphs and scroll position', async ({ page }) => {
  let fail = false;
  await page.route('**/stations/9414290/report?*', route => fail ?
    route.fulfill({ status: 503, json: { error: 'NOAA unavailable.' } }) : route.continue());
  await page.goto('/'); await station(page, '9414290').click();
  await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
  await page.locator('#history-hours').scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => ({ y: scrollY, chart: chart_graph_partial.index }));
  fail = true; await page.getByLabel('History', { exact: true }).selectOption('24');
  await expect(page.locator('#report-status')).toContainText('Previous charts are still displayed');
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(before.chart);
  await expect(page.locator('#weather-charts .highcharts-container')).toHaveCount(4);
  expect(Math.abs(await page.evaluate(() => scrollY) - before.y)).toBeLessThan(2);
});

test('station list still works if the Maps SDK fails to load', async ({ page }) => {
  await page.route('https://maps.googleapis.com/**', route => route.abort());
  await page.goto('/'); await expect(page.locator('#map-status')).toContainText('map is unavailable');
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
});

test('location sorting works only after a user requests it', async ({ context, page }) => {
  await context.grantPermissions(['geolocation']); await context.setGeolocation({ latitude: 46.8, longitude: -92.1 });
  await page.goto('/'); await page.getByRole('button', { name: 'Find stations near me' }).click();
  await expect(page.locator('#location-status')).toContainText('sorted by distance');
  await expect(page.locator('#station-results button').first()).toHaveAttribute('data-station-id', '9099064');
});

test('location requests identify this origin and wait for the existing browser permission flow', async ({ page }) => {
  await page.addInitScript(() => {
    window.locationRequests = [];
    Object.defineProperty(navigator, 'geolocation', { configurable: true, value: {
      getCurrentPosition(success, error, options) {
        window.locationRequests.push({ origin: location.origin, options }); window.locationFailure = error;
      }
    } });
  });
  await page.goto('/'); await expect(station(page, '9414290')).toBeVisible();
  await expect(page.locator('#location-origin')).toHaveText('127.0.0.1:3467');
  await expect(page.getByRole('button', { name: 'Find stations near me' })).toHaveAttribute('aria-describedby', 'location-details');
  expect(await page.evaluate(() => window.locationRequests)).toEqual([]);
  await page.getByRole('button', { name: 'Find stations near me' }).click();
  await expect(page.locator('#location-status')).toContainText('Requesting location for 127.0.0.1:3467');
  await expect(page.locator('#locate')).toBeDisabled();
  await page.evaluate(() => document.querySelector('#locate').dispatchEvent(new MouseEvent('click')));
  expect(await page.evaluate(() => window.locationRequests)).toEqual([{ origin: 'http://127.0.0.1:3467',
    options: { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 } }]);
  await page.evaluate(() => window.locationFailure({ code: 1 }));
  await expect(page.locator('#location-status')).toContainText('Location access for 127.0.0.1:3467 was declined');
  await expect(page.locator('#locate')).toBeEnabled();
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
});

for (const [code, message] of [[2, 'could not be determined'], [3, 'timed out']]) {
  test(`location failure ${code} allows retry and keeps station search usable`, async ({ page }) => {
    await page.addInitScript(code => Object.defineProperty(navigator, 'geolocation', { value: {
      getCurrentPosition(success, error) { error({ code }); }
    } }), code);
    await page.goto('/'); await page.getByRole('button', { name: 'Find stations near me' }).click();
    await expect(page.locator('#location-status')).toContainText(message);
    await expect(page.locator('#locate')).toBeEnabled();
    await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  });
}

test('browsers without a location API retain search and explain the limitation', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(navigator, 'geolocation', { value: undefined }));
  await page.goto('/'); await page.getByRole('button', { name: 'Find stations near me' }).click();
  await expect(page.locator('#location-status')).toContainText('unavailable in this browser or connection');
  await expect(page.locator('#locate')).toBeEnabled();
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
});

test('stations with additional products have purple markers, labels and a discovery filter', async ({ page }) => {
  await page.goto('/'); await expect(page.locator('#result-count')).toContainText('2 matching');
  await expect(station(page, '9414290')).toHaveClass(/extra-products/);
  await expect(station(page, '9414290')).toContainText('Additional:');
  await expect(page.locator('.map-legend')).toContainText('Purple pin = additional products');
  await expect(page.locator('#full_map img[src*="purple_marker"]')).toBeVisible();
  await page.getByLabel('Show stations', {exact: true}).selectOption('additional');
  await expect(page.locator('#result-count')).toHaveText('1 matching locations');
  await expect(station(page, '9099064')).toHaveCount(0);
});

test('future planning and 30-day history update in place and retain shareable settings', async ({ page }) => {
  await page.goto('/?station=9414290'); await expect(page.locator('#future-tides .highcharts-container')).toBeVisible();
  const control = page.getByLabel('History', {exact: true}); await control.scrollIntoViewIfNeeded();
  const before = await page.evaluate(() => ({ y: scrollY, chart: chart_graph_partial.index }));
  await control.selectOption('720');
  await expect(page.locator('#graph-partial .highcharts-subtitle')).toContainText('Past 720 hours');
  await page.getByLabel('Plan ahead', {exact: true}).selectOption('720');
  await expect(page.locator('#planning-intro')).toContainText('next 30 days');
  await expect(page).toHaveURL(/future_hours=720/);
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(before.chart);
  expect(Math.abs(await page.evaluate(() => scrollY) - before.y)).toBeLessThan(2);
  await page.getByLabel('Plan ahead', {exact: true}).selectOption('0');
  await expect(page.locator('#future-tides')).toHaveCount(0);
});

test('observed-minus-predicted graph keeps zero differences and null gaps', async ({ page }) => {
  await page.goto('/?station=9414290');
  await expect(page.locator('#tide-difference .highcharts-container')).toBeVisible();
  expect(await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'tide-difference').series[0].getColumn('y'))).toEqual([0, null, 0]);
  await page.getByLabel('Show stations', {exact: true}).selectOption('tidepredictions');
  await station(page, 'TWC0331').click();
  await expect(page.locator('#departure-note')).toContainText('requires matching');
  await expect(page.locator('#tide-difference')).toHaveCount(0);
});

test('forecast, one-minute observations and flood outlooks are labelled as distinct NOAA products', async ({ page }) => {
  await page.goto('/?station=9414290');
  await expect(page.locator('#forecast-water-level .highcharts-container')).toBeVisible();
  await expect(page.locator('#one-minute-water-level .highcharts-container')).toBeVisible();
  await expect(page.locator('#flood-outlook')).toContainText('12.5%');
  await expect(page.locator('#flood-outlook')).toContainText('above MLLW');
  await expect(page.locator('#context-intro')).toContainText('Model guidance');
  await station(page, '9099064').click();
  await expect(page.locator('#context-intro')).toContainText('No water-level model forecast');
  await expect(page.locator('#forecast-water-level')).toHaveCount(0);
});

test('nearby buoy charts show instrument identity, distance and converted measurements', async ({ page }) => {
  await page.goto('/?station=9414290');
  await expect(page.locator('#buoy-46026 > summary')).toContainText('Offshore test buoy');
  await expect(page.locator('#buoy-46026 > summary')).toContainText('km away');
  await page.locator('#buoy-46026 > summary').click();
  await expect(page.locator('#buoy-46026-wave_height .highcharts-container')).toBeVisible();
  const value = await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'buoy-46026-wave_height').series[0].getColumn('y')[0]);
  expect(value).toBeCloseTo(8.2021, 3);
  await page.getByLabel('Units', {exact: true}).selectOption('metric');
  await expect.poll(() => page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'buoy-46026-wave_height')?.yAxis[0].axisTitle.textStr)).toBe('m');
});

test('failed optional products leave the main report usable and can be retried independently', async ({ page }) => {
  let fail = true, mainRequests = 0;
  page.on('request', r => {if (r.url().includes('/report?')) mainRequests++;});
  await page.route('**/stations/9414290/context?*', route => fail ? route.fulfill({status: 503, json: {error: 'Forecast service unavailable'}}) : route.continue());
  await page.goto('/?station=9414290');
  await expect(chart(page)).toHaveText('San Francisco, CA');
  await expect(page.locator('#context-intro')).toContainText('Forecast service unavailable');
  fail = false; const count = mainRequests;
  await page.getByRole('button', {name: 'Retry additional products'}).click();
  await expect(page.locator('#forecast-water-level .highcharts-container')).toBeVisible();
  expect(mainRequests).toBe(count);
});

test('extra station sensor histories retain their own units and conditional graphs', async ({ page }) => {
  await page.route('**/stations/9414290/report?*', async route => {
    const response = await route.fetch(), payload = await response.json();
    for (const [product, value] of [['conductivity', 42], ['salinity', 32], ['specific_gravity', 1.02], ['visibility', 4], ['air_gap', 60]]) {
      payload.weather_series[product] = payload.observations.map(p => ({...p, value}));
      payload.weather[product] = payload.weather_series[product].at(-1);
    }
    await route.fulfill({response, json: payload});
  });
  await page.goto('/?station=9414290');
  await expect(page.locator('#weather-conductivity')).toContainText('mS/cm');
  await expect(page.locator('#weather-salinity')).toContainText('PSU');
  await expect(page.locator('#weather-visibility')).toContainText('nmi');
  await expect(page.locator('#weather-air_gap')).toContainText('ft');
  await expect(page.locator('#weather-specific_gravity')).not.toContainText('°F');
});


test('overlap selection preserves purple products and the one-click discovery filter', async ({page}) => {
  await page.goto('/'); await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
  await page.evaluate(() => fixtureMap.setZoom(0));
  await page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true}).click();
  const picker=page.getByRole('dialog',{name:'Choose an overlapping station'});
  await expect(picker.locator('.spread-station.extra-products')).toHaveCount(1);
  const toggle=page.getByRole('button',{name:'Show additional products only',exact:true});
  await toggle.click(); await expect(picker).toHaveCount(0);
  await expect(toggle).toHaveAttribute('aria-pressed','true');
  await expect(page.locator('#result-count')).toHaveText('1 matching locations');
  await expect(page.locator('#full_map img[src*="purple_marker"]')).toBeVisible();
  await toggle.click(); await expect(page.locator('#result-count')).toHaveText('2 matching locations');
});

test('new graph tables expose measurements and follow the selected time zone', async ({page}) => {
  await page.goto('/?station=9414290');
  await expect(page.locator('#forecast-water-level .highcharts-container')).toBeVisible();
  await page.locator('#forecast-water-level-data > summary').click();
  await expect(page.locator('#forecast-water-level-data tbody')).toContainText('NOAA OFS model guidance');
  await expect(page.locator('#forecast-water-level-data tbody')).toContainText('ft, MLLW');
  await page.getByLabel('Time', {exact: true}).selectOption('utc');
  await expect(page.locator('#forecast-water-level-data caption')).toContainText('Times: UTC');
});

test('an obsolete optional response cannot paint the newly selected station', async ({page}) => {
  let release; const barrier = new Promise(resolve => {release = resolve;});
  let finished; const done = new Promise(resolve => {finished = resolve;});
  await page.route('**/stations/9414290/context?*', async route => {
    await barrier;
    await route.fulfill({json: {station_id: '9414290', units: 'english', datum: 'MLLW', fetched_at: new Date().toISOString(),
      forecast: [{time: new Date().toISOString(), timestamp: Date.now(), value: 99}], flood_outlook: [], products: [], warnings: []}});
    finished();
  });
  await page.goto('/?station=9414290'); await expect(chart(page)).toHaveText('San Francisco, CA');
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('#context-intro')).toContainText('No water-level model forecast');
  release(); await done;
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await expect(page.locator('#forecast-water-level')).toHaveCount(0);
  await expect(page.locator('#station-summary')).toContainText('IGLD');
});

test('hourly forecasts form a line while a missing forecast hour remains a gap', async ({page}) => {
  await page.route('**/stations/9414290/context?*', async route => {
    const response = await route.fetch(), payload = await response.json();
    const start = Date.now();
    payload.forecast = [0, 1, 3].map(hour => ({timestamp: start + hour * 3600000, value: hour}));
    await route.fulfill({response, json: payload});
  });
  await page.goto('/?station=9414290');
  await expect(page.locator('#forecast-water-level .highcharts-container')).toBeVisible();
  expect(await page.evaluate(() => Highcharts.charts.find(c => c?.renderTo.id === 'forecast-water-level').series[0].getColumn('y'))).toEqual([0, 1, null, 3]);
  await page.locator('#forecast-water-level-data > summary').click();
  await expect(page.locator('#forecast-water-level-data tbody tr')).toHaveCount(4);
});

test('optional rerenders preserve expanded table pages, calendar and keyboard focus', async ({page}) => {
  await page.route('**/stations/9414290/context?*', async route => {
    const response = await route.fetch(), payload = await response.json();
    const start = Date.now();
    payload.one_minute = Array.from({length: 1200}, (_, i) => ({timestamp: start + i * 60000, value: i}));
    await route.fulfill({response, json: payload});
  });
  await page.goto('/?station=9414290');
  const details = page.locator('#one-minute-water-level-data');
  await details.locator('summary').click();
  const more = details.getByRole('button', {name: 'Show more chart data'});
  await more.focus(); await page.keyboard.press('Enter');
  await expect(more).toBeFocused();
  await expect(details.locator('tbody tr')).toHaveCount(1000);
  const calendar = page.locator('#planning-events details');
  await calendar.locator('summary').click();
  await page.getByLabel('Time', {exact: true}).selectOption('utc');
  await expect(details.locator('tbody tr')).toHaveCount(1000);
  await expect(calendar).toHaveAttribute('open', '');
  await page.locator('#buoy-46026 > summary').click();
  await expect(calendar).toHaveAttribute('open', '');
  await expect(details.locator('tbody tr')).toHaveCount(1000);
  await more.focus(); await page.keyboard.press('Enter');
  await expect(details.locator('tbody tr')).toHaveCount(1200);
  await expect(details.locator('summary')).toBeFocused();
});

test('a failed units refresh clears stale flood context and product links', async ({page}) => {
  await page.route('**/stations/9414290/context?*', route => route.request().url().includes('units=metric') ?
    route.fulfill({status: 503, json: {error: 'Context unavailable'}}) : route.continue());
  await page.goto('/?station=9414290');
  await expect(page.locator('#flood-outlook')).toContainText('12.5%');
  await page.getByLabel('Units', {exact: true}).selectOption('metric');
  await expect(page.locator('#context-intro')).toContainText('Context unavailable');
  await expect(page.locator('#flood-outlook')).toHaveCount(0);
  await expect(page.locator('#noaa-extra-products')).toHaveCount(0);
  await expect(chart(page)).toHaveText('San Francisco, CA');
});

test('main measurement pagination restores final-page focus and resets on station selection', async ({page}) => {
  await page.route('**/stations/*/report?*', async route => {
    const response = await route.fetch(), payload = await response.json();
    const start = Date.now() - 2200 * 60000;
    payload.observations = Array.from({length:2200}, (_, i) => ({...payload.observations[0], timestamp:start+i*60000, time:new Date(start+i*60000).toISOString(), value:i/100}));
    payload.predictions=[]; payload.future_predictions=[]; payload.differences=[]; payload.weather_series={}; payload.weather={};
    await route.fulfill({response,json:payload});
  });
  await page.goto('/?station=9414290'); await expect(chart(page)).toHaveText('San Francisco, CA');
  const summary=page.locator('#observations-table > summary'), more=page.locator('#more-measurements');
  await summary.focus(); await page.keyboard.press('Enter');
  await expect(page.locator('#observations-table')).toHaveAttribute('open','');
  await expect(page.locator('#measurement-rows tr')).toHaveCount(1000);
  await more.focus(); await page.keyboard.press('Enter');
  await expect(page.locator('#measurement-rows tr')).toHaveCount(2000); await expect(more).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#measurement-rows tr')).toHaveCount(2200); await expect(summary).toBeFocused();
  await station(page,'9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('#observations-table')).not.toHaveAttribute('open','');
  await summary.focus(); await page.keyboard.press('Enter');
  await expect(page.locator('#observations-table')).toHaveAttribute('open','');
  await expect(page.locator('#measurement-rows tr')).toHaveCount(1000);
});


test('NOAA product disclosures and link focus survive unrelated optional renders', async ({page}) => {
  let release; const barrier = new Promise(resolve => {release=resolve;});
  await page.route('**/stations/9414290/nearby?*', async route => {await barrier; await route.continue();});
  await page.goto('/?station=9414290');
  const details=page.locator('#noaa-extra-products details');
  await details.locator('summary').click();
  const link=details.getByRole('link').first(); await link.focus();
  release(); await expect(page.locator('#buoy-46026 > summary')).toBeVisible();
  await expect(details).toHaveAttribute('open',''); await expect(link).toBeFocused();
  await page.locator('#buoy-46026 > summary').click();
  await expect(details).toHaveAttribute('open','');
  await link.focus(); await page.getByLabel('Time',{exact:true}).selectOption('utc');
  await expect(details).toHaveAttribute('open','');
});


test('overlapping stations can be searched and closed with Escape without changing zoom', async ({page}) => {
  await page.goto('/'); await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
  await page.evaluate(() => fixtureMap.setZoom(0));
  const pin=page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true});
  await pin.focus(); await page.keyboard.press('Enter');
  const picker=page.getByRole('dialog',{name:'Choose an overlapping station'});
  await expect(picker.locator('.spread-station').first()).toBeFocused();
  await picker.getByRole('searchbox',{name:'Search overlapping stations'}).fill('9099064');
  await expect(picker.locator('.spread-station')).toHaveCount(1);
  await expect(picker.locator('.spread-station')).toContainText('Duluth, MN');
  await page.keyboard.press('Escape'); await expect(picker).toHaveCount(0); await expect(pin).toBeFocused();
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom','0');
  await pin.press('Enter'); await expect(picker).toBeVisible();
  await page.setViewportSize({width:700,height:500});
  await expect(picker).toHaveCount(0); await expect(pin).toBeFocused();
});

test('dense overlapping stations have bounded radial pages and search reaches every station', async ({page}) => {
  await page.route('**/stations.json',async route=>{
    const response=await route.fetch(), payload=await response.json();
    const base=payload.stations.find(s=>s.station_id==='9414290');
    payload.stations=Array.from({length:25},(_,i)=>({...base,station_id:String(9414290+i),station_name:`Harbor ${i}`,latitude:base.latitude,longitude:base.longitude}));
    await route.fulfill({response,json:payload});
  });
  await page.goto('/'); await expect(page.locator('#result-count')).toContainText('25 matching');
  await page.locator('#full_map').getByRole('button',{name:'Harbor 0, CA 9414290',exact:true}).click();
  const picker=page.getByRole('dialog',{name:'Choose an overlapping station'});
  await expect(picker.locator('.spread-station')).toHaveCount(6);
  await expect(picker.getByRole('status')).toHaveText('1–6 of 25');
  await picker.getByRole('button',{name:'Next',exact:true}).click();
  await expect(picker.getByRole('status')).toHaveText('7–12 of 25');
  await expect(picker.locator('.spread-station').first()).toBeFocused();
  const boxes=await picker.locator('.spread-station').evaluateAll(nodes=>nodes.map(n=>{const b=n.getBoundingClientRect();return{x:b.x,y:b.y,w:b.width,h:b.height};}));
  for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++)expect(boxes[i].x+boxes[i].w<=boxes[j].x||boxes[j].x+boxes[j].w<=boxes[i].x||boxes[i].y+boxes[i].h<=boxes[j].y||boxes[j].y+boxes[j].h<=boxes[i].y).toBe(true);
  await picker.getByRole('searchbox',{name:'Search overlapping stations'}).fill('Harbor 24');
  await expect(picker.locator('.spread-station')).toHaveCount(1); await expect(picker.locator('.spread-station')).toContainText('Harbor 24, CA');
  await page.evaluate(()=>fixtureMap.setCenter({lat:40,lng:-120})); await expect(picker).toHaveCount(0);
});


test('an isolated individual pin opens its report and restores focus without zooming', async ({page}) => {
  await page.goto('/');
  const pin=page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true});
  await pin.focus(); await page.keyboard.press('Enter');
  await expect(chart(page)).toHaveText('San Francisco, CA');
  await expect(page.locator('.station-spread')).toHaveCount(0);
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom','3');
  await page.getByRole('button',{name:'Close station details'}).click(); await expect(pin).toBeFocused();
});

test('overlapping pins across the date line remain selectable at the current zoom', async ({page}) => {
  await page.route('**/stations.json',async route=>{
    const response=await route.fetch(), payload=await response.json();
    payload.stations=payload.stations.slice(0,2).map((s,i)=>({...s,latitude:37,longitude:i ? -179.9 : 179.9}));
    await route.fulfill({response,json:payload});
  });
  await page.goto('/'); await expect(page.locator('#result-count')).toContainText('2 matching');
  await page.evaluate(()=>{fixtureMap.setCenter({lat:37,lng:180});fixtureMap.setZoom(8);});
  await page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true}).click();
  await expect(page.locator('.spread-station')).toHaveCount(2);
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom','8');
});


test('the radial picker stays within the viewport on tall maps and short screens', async ({page}) => {
  await page.setViewportSize({width:390,height:350});
  await page.goto('/'); await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
  await page.evaluate(()=>fixtureMap.setZoom(0));
  const pin=page.locator('#full_map').getByRole('button',{name:'San Francisco, CA 9414290',exact:true});
  await pin.focus();
  const before=await page.evaluate(()=>scrollY);
  await page.keyboard.press('Enter');
  const picker=page.getByRole('dialog',{name:'Choose an overlapping station'});
  await expect(picker).toBeVisible();
  const boxes=await picker.locator('input, button').evaluateAll(nodes=>nodes.filter(n=>!n.disabled).map(n=>{const b=n.getBoundingClientRect();return{top:b.top,bottom:b.bottom,left:b.left,right:b.right};}));
  for(const box of boxes){expect(box.top).toBeGreaterThanOrEqual(0);expect(box.bottom).toBeLessThanOrEqual(350);expect(box.left).toBeGreaterThanOrEqual(0);expect(box.right).toBeLessThanOrEqual(390);}
  expect(await page.evaluate(()=>scrollY)).toBe(before);
});


test('five overlapping station choices have separate touch targets on short screens', async ({page}) => {
  await page.setViewportSize({width:390,height:350});
  await page.route('**/stations.json',async route=>{
    const response=await route.fetch(), payload=await response.json();
    const base=payload.stations.find(s=>s.station_id==='9414290');
    payload.stations=Array.from({length:5},(_,i)=>({...base,station_id:String(9414290+i),station_name:`Harbor ${i}`}));
    await route.fulfill({response,json:payload});
  });
  await page.goto('/'); await expect(page.locator('#result-count')).toContainText('5 matching');
  await page.locator('#full_map').getByRole('button',{name:'Harbor 0, CA 9414290',exact:true}).click();
  const choices=page.locator('.spread-station'); await expect(choices).toHaveCount(5);
  const boxes=await choices.evaluateAll(nodes=>nodes.map(n=>{const b=n.getBoundingClientRect();return{x:b.x,y:b.y,w:b.width,h:b.height};}));
  for(let i=0;i<boxes.length;i++)for(let j=i+1;j<boxes.length;j++)expect(boxes[i].x+boxes[i].w<=boxes[j].x||boxes[j].x+boxes[j].w<=boxes[i].x||boxes[i].y+boxes[i].h<=boxes[j].y||boxes[j].y+boxes[j].h<=boxes[i].y).toBe(true);
});
