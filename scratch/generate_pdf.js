const puppeteer = require('C:/Users/amjat/AppData/Roaming/npm/node_modules/md-to-pdf/node_modules/puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  console.log('Launching browser...');
  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();
  
  const htmlPath = path.resolve(__dirname, 'revenue_strategy.html');
  console.log('Loading HTML from:', htmlPath);
  await page.goto('file:///' + htmlPath.replace(/\\/g, '/'), { waitUntil: 'networkidle0', timeout: 30000 });
  
  const outputPath = path.resolve(__dirname, '..', 'CaseFlow_Revenue_Strategy.pdf');
  console.log('Generating PDF to:', outputPath);
  await page.pdf({
    path: outputPath,
    format: 'A4',
    printBackground: true,
    margin: { top: '20mm', bottom: '20mm', left: '18mm', right: '18mm' },
  });
  
  console.log('PDF generated successfully!');
  console.log('Location:', outputPath);
  await browser.close();
})();
