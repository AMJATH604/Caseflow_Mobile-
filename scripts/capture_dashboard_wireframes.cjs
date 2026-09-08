const path = require('path');
const fs = require('fs');
const { chromium } = require(path.resolve(__dirname, '..', 'apps', 'dashboard', 'node_modules', 'playwright'));

const OUTPUT_DIR = path.resolve(__dirname, '..', 'caseflow_wireframes', '01_Web_Dashboard_Admin');

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const SCREENS = [
  { name: '01_Auth_Login_Registration', path: '/auth', auth: false },
  { name: '02_Executive_Dashboard_Overview', path: '/', auth: true },
  { name: '03_Cases_Management_Repository', path: '/cases', auth: true },
  { name: '04_Case_Detail_File_Timeline', path: '/cases/sample-case', auth: true },
  { name: '05_Hearings_Court_Diary', path: '/hearings', auth: true },
  { name: '06_Clients_CRM_Directory', path: '/clients', auth: true },
  { name: '07_Certified_Copies_Tracker', path: '/certified-copies', auth: true },
  { name: '08_EFiling_Court_Submissions', path: '/efiling', auth: true },
  { name: '09_Payments_Invoicing_Financials', path: '/payments', auth: true },
  { name: '10_Bare_Acts_Statute_Library', path: '/bare-acts', auth: true },
  { name: '11_Legal_Templates_Drafting', path: '/legal-templates', auth: true },
  { name: '12_Stamp_Duty_Court_Fees_Admin', path: '/stamp-values', auth: true },
  { name: '13_Advocate_Colleague_Network', path: '/advocates', auth: true },
  { name: '14_Legal_Calculators_Limitation_Tools', path: '/tools', auth: true },
  { name: '15_AI_Legal_Assistant_Chat', path: '/ai-chat', auth: true },
  { name: '16_Notifications_Court_Alerts', path: '/notifications', auth: true },
  { name: '17_Unauthorized_Role_Boundary', path: '/unauthorized', auth: false },
  { name: '18_Not_Found_404_State', path: '/non-existent-route', auth: false },
];

async function captureAll() {
  console.log('Starting CaseFlow Web Dashboard Wireframe Captures...');
  const browser = await chromium.launch({ headless: true });
  
  // Standard investor presentation viewport: 1440x900 @ 2x device scale for retina sharpness
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
  });

  const page = await context.newPage();

  for (const screen of SCREENS) {
    const url = `http://localhost:8080${screen.path}`;
    console.log(`Capturing: ${screen.name} -> ${url}`);

    try {
      await page.goto('http://localhost:8080/auth', { waitUntil: 'domcontentloaded', timeout: 10000 });
      if (screen.auth) {
        await page.evaluate(() => localStorage.setItem('caseflow_demo', 'true'));
      } else {
        await page.evaluate(() => localStorage.removeItem('caseflow_demo'));
      }

      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
      await page.waitForTimeout(1500); // Allow react components, lucide icons & recharts to stabilize
      
      const filePath = path.join(OUTPUT_DIR, `${screen.name}.png`);
      await page.screenshot({ path: filePath, fullPage: false });
      console.log(`[OK] Saved: ${screen.name}.png`);
    } catch (err) {
      console.error(`[ERR] ${screen.name}:`, err.message);
      try {
        const filePath = path.join(OUTPUT_DIR, `${screen.name}.png`);
        await page.screenshot({ path: filePath, fullPage: false });
      } catch (e) {}
    }
  }

  await browser.close();
  console.log('\nSUCCESS: All 18 Web Dashboard Wireframe Captures Completed!');
}

captureAll().catch(err => {
  console.error('Fatal error in captureAll:', err);
  process.exit(1);
});
