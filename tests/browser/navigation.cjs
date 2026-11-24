// Follow the public UI when older data regressions reach a control/graph that now lives in a tab/drawer.
// No DOM state is changed by this helper. layout.spec.cjs separately verifies the collapsed defaults.
async function reveal(page, locator) {
  if (await locator.isVisible()) return;
  await locator.waitFor({state:'attached'});
  const context=await locator.evaluate(node=>{
    const panel=node.closest('[role="tabpanel"]'),drawer=node.closest('.drawer');
    return {view:panel?.id.replace('view-',''),drawer:drawer?.id};
  });
  if(context.drawer){
    const name=context.drawer==='station-list'?'List':'Filters';
    if(await page.locator('#'+context.drawer).isHidden())await page.getByRole('button',{name,exact:true}).click();
  }
  if(context.view&&await page.locator('#view-'+context.view).isHidden())await page.getByRole('tab',{name:({now:'Now',tides:'Tides',weather:'Weather',history:'History'})[context.view],exact:true}).click();
  const summary=await locator.evaluate(node=>node.tagName==='SUMMARY');
  const details=await locator.locator('xpath=ancestor::details'+(summary?'[position()>1]':'')).all();
  for(const item of details){if(await item.getAttribute('open')===null)await item.locator(':scope > summary').click();}
}
module.exports={reveal};
