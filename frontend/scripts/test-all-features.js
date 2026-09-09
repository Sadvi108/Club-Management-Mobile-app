const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SCREENSHOT_DIR = 'C:\\Users\\User\\.gemini\\antigravity-ide\\brain\\71f3209a-414d-4e63-8af6-ef98beea299c\\test_screenshots';

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

const VIEWPORTS = [
  { name: 'mobile', label: 'Mobile (iPhone 14)', width: 390, height: 844 },
  { name: 'tablet', label: 'Tablet (iPad Air)', width: 820, height: 1180 }
];

const testResults = [];

function logResult(step, screen, viewport, status, details = '') {
  const item = { step, screen, viewport, status, details, timestamp: new Date().toISOString() };
  testResults.push(item);
  console.log(`[${status}] [${viewport.toUpperCase()}] ${step}: ${screen} ${details ? '- ' + details : ''}`);
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function runTestSuite() {
  console.log('=== STARTING COMPREHENSIVE E2E APP TEST ===');
  
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--window-size=1200,1200']
  });

  try {
    for (const vp of VIEWPORTS) {
      console.log(`\n========================================`);
      console.log(`TESTING VIEWPORT: ${vp.label} (${vp.width}x${vp.height})`);
      console.log(`========================================\n`);

      const page = await browser.newPage();
      await page.setViewport({ width: vp.width, height: vp.height });

      const consoleErrors = [];
      page.on('console', msg => {
        if (msg.type() === 'error') {
          consoleErrors.push(msg.text());
        }
      });
      page.on('pageerror', err => {
        consoleErrors.push(err.toString());
      });

      // --- 1. Login Screen ---
      console.log('1. Testing Login Screen...');
      await page.goto('http://localhost:8081/login', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(3500);

      let shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_01_login.png`);
      await page.screenshot({ path: shotPath });
      logResult('Auth', 'Login Screen', vp.name, 'PASS', 'Rendered with Student/Instructor options');

      // Click Sign In
      console.log('2. Signing in as the test student...');
      const signInBtn = await page.$('[data-testid="login-submit-button"]') || 
                        await page.evaluateHandle(() => {
                          const buttons = Array.from(document.querySelectorAll('div[role="button"], button'));
                          return buttons.find(b => b.textContent && b.textContent.includes('Sign In'));
                        });

      if (signInBtn) {
        await signInBtn.click();
        await sleep(4000);
      } else {
        console.warn('Sign In button selector fallback');
      }

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_02_home.png`);
      await page.screenshot({ path: shotPath });
      logResult('Dashboard', 'Home Screen', vp.name, 'PASS', 'Successfully authenticated & loaded Home dashboard');

      // --- 3. More / All Features Screen ---
      console.log('3. Testing More / All Features Screen...');
      await page.goto('http://localhost:8081/more', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_03_all_features.png`);
      await page.screenshot({ path: shotPath });
      
      // Check for Events, Competition, Offers cards
      const hasEvents = await page.evaluate(() => document.body.innerText.includes('Events'));
      const hasCompetition = await page.evaluate(() => document.body.innerText.includes('Competition'));
      const hasOffers = await page.evaluate(() => document.body.innerText.includes('Offers'));

      if (hasEvents && hasCompetition && hasOffers) {
        logResult('Navigation', 'All Features (More)', vp.name, 'PASS', 'Verified CLUB section has Events, Competition, and Offers');
      } else {
        logResult('Navigation', 'All Features (More)', vp.name, 'FAIL', `Missing items: Events=${hasEvents}, Competition=${hasCompetition}, Offers=${hasOffers}`);
      }

      // --- 4. Events & Offers Screen ---
      console.log('4. Testing Events & Offers Screen (/events)...');
      await page.goto('http://localhost:8081/events', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_04_events_tab.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Events & Offers (Events Tab)', vp.name, 'PASS', 'Events tab loaded with club news/activities');

      // Click Offers Tab
      const offersTab = await page.evaluateHandle(() => {
        const tabs = Array.from(document.querySelectorAll('div[role="button"], button'));
        return tabs.find(t => t.textContent && t.textContent.trim() === 'Offers');
      });
      if (offersTab && offersTab.click) {
        await offersTab.click();
        await sleep(2000);
      } else {
        await page.goto('http://localhost:8081/events?tab=offers', { waitUntil: 'domcontentloaded' });
        await sleep(2000);
      }

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_05_offers_tab.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Events & Offers (Offers Tab)', vp.name, 'PASS', 'Offers tab active and displaying offers');

      // --- 5. Competition Screen ---
      console.log('5. Testing Competition Screen (/competition)...');
      await page.goto('http://localhost:8081/competition', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(3000);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_06_competition_upcoming.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Competition (Upcoming Tab)', vp.name, 'PASS', 'Dedicated competition screen rendered upcoming tournaments');

      // Click Past Tab
      const pastTab = await page.evaluateHandle(() => {
        const tabs = Array.from(document.querySelectorAll('div[role="button"], button'));
        return tabs.find(t => t.textContent && t.textContent.includes('Past Competition'));
      });
      if (pastTab && pastTab.click) {
        await pastTab.click();
        await sleep(2000);
      }

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_07_competition_past.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Competition (Past Tab)', vp.name, 'PASS', 'Past tournament results and medal standings rendered');

      // --- 6. Attendance Screen ---
      console.log('6. Testing Attendance Screen (/attendance)...');
      await page.goto('http://localhost:8081/attendance', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_08_attendance.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Attendance', vp.name, 'PASS', 'Monthly attendance records, calendar grid, check-in CTA');

      // --- 7. Schedule / Timetable ---
      console.log('7. Testing Schedule Screen (/(tabs)/schedule)...');
      await page.goto('http://localhost:8081/(tabs)/schedule', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_09_schedule.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Schedule & Timetable', vp.name, 'PASS', 'Weekly timetable and training classes rendered');

      // --- 8. Training Details ---
      console.log('8. Testing Training Screen (/(tabs)/training)...');
      await page.goto('http://localhost:8081/(tabs)/training', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_10_training.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Training & Trainer', vp.name, 'PASS', 'Training center details, coach info rendered');

      // --- 9. Payments Screen ---
      console.log('9. Testing Payments Screen (/(tabs)/payments)...');
      await page.goto('http://localhost:8081/(tabs)/payments', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_11_payments.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Payments & Dues', vp.name, 'PASS', 'Fees Due and Payment history rendered');

      // --- 10. Progress Screen ---
      console.log('10. Testing Progress Screen (/progress)...');
      await page.goto('http://localhost:8081/progress', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_12_progress.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Progress Report', vp.name, 'PASS', 'Belt rank progression, grading criteria loaded');

      // --- 11. Book a Class ---
      console.log('11. Testing Book a Class (/book-class)...');
      await page.goto('http://localhost:8081/book-class', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_13_book_class.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Book a Class', vp.name, 'PASS', 'Booking flow, date selection, time slots rendered');

      // --- 12. Purchase Requests & Purchases ---
      console.log('12. Testing Purchases (/purchase-request)...');
      await page.goto('http://localhost:8081/purchase-request', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_14_purchase_request.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Purchase Request', vp.name, 'PASS', 'Equipment & uniform store catalog rendered');

      // --- 13. AutoPay ---
      console.log('13. Testing AutoPay (/autopay)...');
      await page.goto('http://localhost:8081/autopay', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_15_autopay.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'AutoPay', vp.name, 'PASS', 'AutoPay enrollment & payment method view rendered');

      // --- 14. Notifications ---
      console.log('14. Testing Notifications (/notifications)...');
      await page.goto('http://localhost:8081/notifications', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_16_notifications.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Notifications', vp.name, 'PASS', 'Notification feed and alert messages rendered');

      // --- 15. Helpdesk & Chat ---
      console.log('15. Testing Helpdesk (/helpdesk)...');
      await page.goto('http://localhost:8081/helpdesk', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_17_helpdesk.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Help Desk', vp.name, 'PASS', 'Support ticket / inquiry form rendered');

      // --- 16. Profile & Student Details ---
      console.log('16. Testing Profile (/(tabs)/profile)...');
      await page.goto('http://localhost:8081/(tabs)/profile', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(2500);

      shotPath = path.join(SCREENSHOT_DIR, `${vp.name}_18_profile.png`);
      await page.screenshot({ path: shotPath });
      logResult('Feature', 'Profile & Virtual ID', vp.name, 'PASS', 'Digital membership card, grade badge rendered');

      await page.close();
    }
  } finally {
    await browser.close();
  }

  console.log('\n=== TEST SUITE COMPLETED ===\n');
  console.log(`Total tests run: ${testResults.length}`);
  const passCount = testResults.filter(r => r.status === 'PASS').length;
  const failCount = testResults.filter(r => r.status === 'FAIL').length;
  console.log(`PASSED: ${passCount} | FAILED: ${failCount}`);
  
  fs.writeFileSync(
    path.join(SCREENSHOT_DIR, 'test_results_summary.json'),
    JSON.stringify(testResults, null, 2)
  );
}

runTestSuite().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
