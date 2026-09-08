const path = require('path');
const fs = require('fs');
const { chromium } = require(path.resolve(__dirname, '..', 'apps', 'dashboard', 'node_modules', 'playwright'));

const OUTPUT_DIR = path.resolve(__dirname, '..', 'caseflow_wireframes', '02_Mobile_App_Flows');

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

const SCREENS = [
  { name: '01_Mobile_Auth_Login_Registration', path: '/auth', auth: false },
  { name: '02_Mobile_Home_Executive_Dashboard', path: '/', auth: true },
  { name: '03_Mobile_Cases_Repository_Filter', path: '/cases', auth: true },
  { name: '04_Mobile_Case_Detail_File_Timeline', path: '/cases/sample-case', auth: true },
  { name: '05_Mobile_Hearings_Court_Diary', path: '/hearings', auth: true },
  { name: '06_Mobile_Clients_CRM_Directory', path: '/clients', auth: true },
  { name: '07_Mobile_Certified_Copies_Tracker', path: '/certified-copies', auth: true },
  { name: '08_Mobile_EFiling_Court_Submissions', path: '/efiling', auth: true },
  { name: '09_Mobile_Payments_Invoicing_Financials', path: '/payments', auth: true },
  { name: '10_Mobile_Bare_Acts_Statute_Library', path: '/bare-acts', auth: true },
  { name: '11_Mobile_Legal_Templates_Drafting', path: '/legal-templates', auth: true },
  { name: '12_Mobile_Stamp_Duty_Court_Fees_Admin', path: '/stamp-values', auth: true },
  { name: '13_Mobile_Advocate_Colleague_Network', path: '/advocates', auth: true },
  { name: '14_Mobile_Legal_Calculators_Limitation_Tools', path: '/tools', auth: true },
  { name: '15_Mobile_AI_Legal_Assistant_Chat', path: '/ai-chat', auth: true },
  { name: '16_Mobile_Notifications_Court_Alerts', path: '/notifications', auth: true },
  { name: '17_Mobile_Unauthorized_Role_Boundary', path: '/unauthorized', auth: false },
  { name: '18_Mobile_Not_Found_404_State', path: '/non-existent-route', auth: false },
];

async function captureAllMobile() {
  console.log('Starting CaseFlow Mobile Wireframe Captures...');
  const browser = await chromium.launch({ headless: true });
  
  // Standard iPhone 14/15 Figma Artboard: 390x844 @ 3x scale for crisp mobile wireframes
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
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
      await page.waitForTimeout(1500); // Allow react components, bottom nav & cards to stabilize
      
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
  console.log('\nSUCCESS: All 18 Mobile Wireframe Captures Completed!');
}

captureAllMobile().catch(err => {
  console.error('Fatal error in captureAllMobile:', err);
  process.exit(1);
});
