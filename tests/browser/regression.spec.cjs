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

test('replacing a station leaves one current chart and shareable URL', async ({ page }) => {
  await page.goto('/'); await station(page, '9414290').click(); await expect(chart(page)).toHaveText('San Francisco, CA');
  await station(page, '9099064').click(); await expect(chart(page)).toHaveText('Duluth, MN');
  await expect(page.locator('.highcharts-container')).toHaveCount(1);
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
  fail = false; await page.getByRole('button', { name: 'Retry station data' }).click();
  await expect(chart(page)).toHaveText('San Francisco, CA');
});

test('prediction-only locations render without pretending to have live observations', async ({ page }) => {
  await page.goto('/'); await page.getByLabel('Show stations', { exact: true }).selectOption('tidepredictions');
  await station(page, 'TWC0331').click(); await expect(chart(page)).toHaveText('Prediction Harbor, CA');
  await expect(page.locator('.latest-reading')).toHaveText('No water-level observation available.');
  expect(await page.evaluate(() => chart_graph_partial.series.map(s => s.name))).toEqual(['Predicted high/low events']);
  expect(await page.evaluate(() => chart_graph_partial.series[0].type)).toBe('scatter');
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
