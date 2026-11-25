const {test,expect}=require('@playwright/test');
const path=require('node:path');
test.beforeEach(async({page})=>{
 page.testErrors=[];page.on('pageerror',e=>page.testErrors.push(e.message));
 await page.route('https://maps.googleapis.com/**',r=>r.fulfill({path:path.join(__dirname,'maps-fixture.js'),contentType:'application/javascript'}));
});
test.afterEach(async({page})=>expect(page.testErrors).toEqual([]));
const phrases={
 en:{find:'Find a station',tides:'Tides',weather:'Weather',history:'History',observed:'Observed water level',loaded:'Historical data loaded.'},
 es:{find:'Buscar una estación',tides:'Mareas',weather:'Meteorología',history:'Historial',observed:'Nivel del agua observado',loaded:'Datos históricos cargados.'},
 fr:{find:'Rechercher une station',tides:'Marées',weather:'Météo',history:'Historique',observed:'Niveau d’eau observé',loaded:'Données historiques chargées.'},
 de:{find:'Station suchen',tides:'Gezeiten',weather:'Wetter',history:'Verlauf',observed:'Beobachteter Wasserstand',loaded:'Historische Daten geladen.'}
};
for(const [locale,label] of Object.entries(phrases))test(`language ${locale} translates reports and preserves source identifiers`,async({page},info)=>{
 await page.goto(`/?locale=${locale}&station=9099064&units=english&zone=station`);
 await expect(page.locator('html')).toHaveAttribute('lang',locale);
 await expect(page.locator('#station-search')).toHaveAttribute('placeholder',label.find);
 await expect(page.locator('#station-heading')).toHaveText('Duluth, MN');
 await expect(page.locator('.latest-reading')).toContainText(locale==='en'?'602.18':'602,18');
 await page.getByRole('tab',{name:label.tides,exact:true}).click();
 await expect(page.locator('#graph-partial .highcharts-legend')).toContainText(label.observed);
 await page.getByRole('tab',{name:label.weather,exact:true}).click();
 await expect(page.locator('#weather-wind .highcharts-container')).toBeVisible();
 await page.getByRole('tab',{name:label.history,exact:true}).click();
 await page.locator('#history-start').fill('2020-01-01');await page.locator('#history-end').fill('2020-01-02');
 await page.locator('#history-form button[type=submit]').click();
 await expect(page.locator('#history-status')).toContainText(label.loaded);
 const download=page.waitForEvent('download');await page.locator('#history-export').click();
 expect((await download).suggestedFilename()).toContain('9099064');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:info.outputPath(`language-${locale}.png`)});
});
test('language switching preserves station, units, time zone and historical dates',async({page})=>{
 await page.goto('/?locale=en&station=9414290&units=metric&zone=station&begin_date=2020-01-01&end_date=2020-01-02');
 await expect(page.locator('#history-status')).toContainText('Historical data loaded.');
 await page.locator('#language-select').selectOption('es');
 await expect(page.locator('html')).toHaveAttribute('lang','es');
 await expect(page.locator('#history-status')).toContainText('Datos históricos cargados.');
 const params=new URL(page.url()).searchParams;
 expect(params.get('station')).toBe('9414290');expect(params.get('units')).toBe('metric');
 expect(params.get('zone')).toBe('station');expect(params.get('begin_date')).toBe('2020-01-01');
 await page.goto('/');await expect(page.locator('html')).toHaveAttribute('lang','es');
 await page.goto('/?locale=en');await expect(page.locator('html')).toHaveAttribute('lang','en');
});
test('German labels fit a narrow phone without hiding footer or language control',async({page})=>{
 await page.setViewportSize({width:320,height:568});await page.goto('/?locale=de');
 await expect(page.locator('#language-select')).toBeInViewport();await expect(page.getByRole('contentinfo')).toBeInViewport();
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.locator('#station-search').fill('9414290');await page.locator('#station-results button[data-station-id="9414290"]').click();
 await page.locator('#expand-station').click();const panel=await page.locator('#station-panel').boundingBox();
 expect(panel.y+panel.height).toBeLessThanOrEqual(568);
});
