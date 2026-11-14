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

test('numbered clusters explain their count and expand into individual station pins', async ({ page }) => {
  await page.goto('/'); await expect(page.getByRole('region', { name: 'Map', exact: true })).toBeVisible();
  await expect(page.locator('.map-legend')).toContainText('Number = nearby stations grouped together');
  await page.evaluate(() => fixtureMap.setZoom(0));
  await page.getByRole('button', { name: '2 stations; zoom in', exact: true }).click();
  await expect(page.locator('#full_map')).toHaveAttribute('data-zoom', '2');
  await expect(page.getByRole('button', { name: 'San Francisco, CA 9414290', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Duluth, MN 9099064', exact: true })).toBeVisible();
});

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
  expect(await page.evaluate(() => chart_graph_partial.index)).toBe(index);
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
