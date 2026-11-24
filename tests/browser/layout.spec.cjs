const {test,expect}=require('@playwright/test');
const path=require('node:path');
test.beforeEach(async({page})=>{
  const errors=[];page.on('pageerror',e=>errors.push(e.message));page.testErrors=errors;
  await page.route('https://maps.googleapis.com/**',r=>r.fulfill({path:path.join(__dirname,'maps-fixture.js'),contentType:'application/javascript'}));
});
test.afterEach(async({page})=>expect(page.testErrors).toEqual([]));
const select=async page=>{await page.getByLabel('Find a station',{exact:true}).fill('9414290');await page.locator('#station-results button[data-station-id="9414290"]').click();await expect(page.locator('.latest-reading')).toContainText('MLLW');};
test('map-first home keeps search and map visible with filters and results tucked away',async({page})=>{
  await page.goto('/');await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
  await expect(page.locator('#station-list')).toBeHidden();await expect(page.locator('#station-filters')).toBeHidden();
  const bounds=await page.locator('#full_map').boundingBox(),size=page.viewportSize();expect(bounds.y).toBeLessThan(150);expect(bounds.height).toBeGreaterThan(size.height*.5);
  await page.getByRole('button',{name:'Filters',exact:true}).click();await expect(page.getByLabel('Highlight product',{exact:true})).toBeVisible();
  await page.getByRole('button',{name:'List',exact:true}).click();await expect(page.locator('#station-filters')).toBeHidden();await expect(page.locator('#station-list')).toBeVisible();
  await page.getByRole('button',{name:'Close station list',exact:true}).click();await expect(page.getByRole('button',{name:'List',exact:true})).toBeFocused();
});
test('compact station summary opens beside or below the map and tabs reflow charts',async({page})=>{
  await page.goto('/');await select(page);
  await expect(page.getByRole('tab',{name:'Now',exact:true})).toHaveAttribute('aria-selected','true');
  await expect(page.locator('#view-tides')).toBeHidden();await expect(page.locator('#view-weather')).toBeHidden();
  await expect(page.locator('#station-heading')).toHaveText('San Francisco, CA');await expect(page.locator('#station-code')).toHaveText('NOAA 9414290');
  const map=await page.locator('#full_map').boundingBox(),panel=await page.locator('#station-panel').boundingBox();
  if(page.viewportSize().width>=900)expect(panel.x).toBeGreaterThan(map.x+map.width-2);else expect(panel.y).toBeGreaterThan(map.y+map.height-2);
  await page.getByRole('tab',{name:'Tides',exact:true}).click();await expect(page.locator('#graph-partial .highcharts-container')).toBeVisible();
  const chart=await page.locator('#graph-partial .highcharts-container').boundingBox();expect(chart.width).toBeLessThanOrEqual(panel.width);
  await page.getByRole('tab',{name:'Weather',exact:true}).click();await expect(page.locator('#weather-wind')).toBeVisible();
  await page.getByRole('tab',{name:'History',exact:true}).click();await expect(page.getByLabel('Start date (UTC)',{exact:true})).toBeVisible();
});
test('tabs support arrow keys, sharing and a historical deep link',async({page})=>{
  await page.goto('/?station=9414290&tab=history&begin_date=2020-01-01&end_date=2020-03-31');
  await expect(page.getByRole('tab',{name:'History',exact:true})).toHaveAttribute('aria-selected','true');await expect(page.locator('#history-status')).toContainText('Historical data loaded.');
  await page.getByRole('tab',{name:'History',exact:true}).focus();await page.keyboard.press('Home');await expect(page.getByRole('tab',{name:'Now',exact:true})).toBeFocused();
  await page.keyboard.press('ArrowRight');await expect(page.getByRole('tab',{name:'Tides',exact:true})).toHaveAttribute('aria-selected','true');await expect(page).toHaveURL(/tab=tides/);
});
test('drawers close with Escape and short-screen panel expansion keeps the map reachable',async({page})=>{
  await page.goto('/');await page.getByRole('button',{name:'Filters',exact:true}).click();await page.getByLabel('Show stations',{exact:true}).focus();await page.keyboard.press('Escape');
  await expect(page.locator('#station-filters')).toBeHidden();await expect(page.getByRole('button',{name:'Filters',exact:true})).toBeFocused();await select(page);
  if(page.viewportSize().width<900){await page.getByRole('button',{name:'Expand station panel',exact:true}).click();await expect(page.getByRole('button',{name:'Collapse station panel',exact:true})).toHaveAttribute('aria-expanded','true');await expect(page.getByRole('button',{name:'Center on your location',exact:true})).toBeVisible();}
  await page.getByRole('button',{name:'Close station details',exact:true}).click();await expect(page.locator('#station-panel')).toBeHidden();
});
test('automatic updates preserve an open station detail and its focus in the compact panel',async({page})=>{
  await page.clock.install();let reports=0;page.on('request',r=>{if(r.url().includes('/report?'))reports++;});
  await page.goto('/?station=9414290');await expect(page.locator('.latest-reading')).toContainText('MLLW');
  const summary=page.locator('#station-details > summary');await summary.click();await summary.focus();
  await page.clock.fastForward(6*60000);await expect.poll(()=>reports).toBe(2);
  await expect(page.locator('#station-charts')).not.toHaveAttribute('aria-busy','true');await expect(page.locator('#station-details')).toHaveAttribute('open','');await expect(page.locator('#station-details > summary')).toBeFocused();
});
test('panel scrolling and chart ranges survive refresh while tabs remember their positions',async({page})=>{
  await page.clock.install();let reports=0;page.on('request',r=>{if(r.url().includes('/report?'))reports++;});
  await page.goto('/?station=9414290&tab=tides');await expect(page.locator('#graph-partial .highcharts-container')).toBeVisible();
  await page.locator('#forecast-products > summary').click();await expect(page.locator('#forecast-water-level .highcharts-container')).toBeVisible();
  const body=page.locator('.station-body');await page.locator('#one-minute-water-level').scrollIntoViewIfNeeded();const scroll=await body.evaluate(n=>n.scrollTop);expect(scroll).toBeGreaterThan(0);
  await page.clock.fastForward(6*60000);await expect.poll(()=>reports).toBe(2);await expect(page.locator('#station-charts')).not.toHaveAttribute('aria-busy','true');expect(await body.evaluate(n=>n.scrollTop)).toBe(scroll);
  await page.getByRole('tab',{name:'Now',exact:true}).click();expect(await body.evaluate(n=>n.scrollTop)).toBe(0);
  await page.getByRole('tab',{name:'Tides',exact:true}).click();expect(await body.evaluate(n=>n.scrollTop)).toBe(scroll);
});
test('partial refresh warnings remain visible with fresh readings in every report view',async({page})=>{
  await page.clock.install();let partial=false;
  await page.route('**/stations/9414290/report?*',async route=>{
    const response=await route.fetch(),payload=await response.json();
    if(partial){
      payload.failed_products=['predictions','weather_series.wind'];payload.predictions=[];payload.weather_series.wind=[];delete payload.weather.wind;
      payload.warnings=[{product:'predictions',message:'Temporary upstream failure'},{product:'wind',message:'Temporary upstream failure'}];
    }
    await route.fulfill({response,json:payload});
  });
  await page.goto('/?station=9414290&tab=weather');await expect(page.locator('#weather-wind')).toBeVisible();
  partial=true;await page.clock.fastForward(6*60000);
  const warnings=page.locator('#report-warnings');await expect(warnings).toContainText('Previous data for those products remain displayed');
  await expect(page.locator('#report-status')).toHaveText('Station data loaded.');
  for(const name of ['Weather','Tides','History','Now']){
    await page.getByRole('tab',{name,exact:true}).click();await expect(warnings).toBeVisible();await expect(warnings).toContainText('predictions: Temporary upstream failure');
  }
});
for(const failed of [false,true]){
  test(`copy-link feedback stays visible when clipboard ${failed?'fails':'succeeds'}`,async({page})=>{
    await page.addInitScript(failed=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{if(failed)throw new Error('Clipboard declined');}}}),failed);
    await page.goto('/?station=9414290');await expect(page.locator('.latest-reading')).toContainText('MLLW');
    await page.getByRole('button',{name:'Copy station link',exact:true}).click();
    const status=page.locator('#report-status');await expect(status).toHaveText(failed?'Copy the station link from your address bar.':'Station link copied.');
    expect(await status.evaluate(n=>n.getBoundingClientRect().height)).toBeGreaterThan(10);
  });
  test(`catalog ${failed?'failure':'empty response'} is explained with discovery drawers closed`,async({page})=>{
    await page.route('**/stations.json',async route=>{
      if(failed)return route.fulfill({status:503,json:{error:'Catalog unavailable'}});
      const response=await route.fetch(),payload=await response.json();payload.stations=[];await route.fulfill({response,json:payload});
    });
    await page.goto('/');await expect(page.getByRole('region',{name:'Map',exact:true})).toBeVisible();
    await expect(page.locator('#station-filters')).toBeHidden();await expect(page.locator('#station-list')).toBeHidden();
    await expect(page.locator('#catalog-alert')).toBeVisible();await expect(page.locator('#catalog-alert')).toContainText('Please reload to retry.');
  });
}
