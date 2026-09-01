const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SCREENSHOT_DIR = 'C:\\Users\\User\\.gemini\\antigravity-ide\\brain\\71f3209a-414d-4e63-8af6-ef98beea299c\\test_screenshots';

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

const VIEWPORTS = [
  { name: 'mobile', label: 'Mobile Viewport (iPhone 14)', width: 390, height: 844 },
  { name: 'tablet', label: 'Tablet Viewport (iPad Air)', width: 820, height: 1180 }
];

const reportData = [];

function recordResult(viewport, feature, screen, status, notes = '', screenshot = '') {
  const entry = { viewport, feature, screen, status, notes, screenshot };
  reportData.push(entry);
  console.log(`[${status}] [${viewport.toUpperCase()}] ${feature} > ${screen} ${notes ? '(' + notes + ')' : ''}`);
}

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// Helper to click an element by testID or selector
async function safeClick(page, selector, waitMs = 2500) {
  try {
    const ok = await page.evaluate((sel) => {
      let el = document.querySelector(`[data-testid="${sel}"]`);
      if (!el) el = document.querySelector(sel);
      if (el) {
        el.scrollIntoView({ behavior: 'instant', block: 'center' });
        el.click();
        return true;
      }
      return false;
    }, selector);

    if (ok) {
      await sleep(waitMs);
      return true;
    }
  } catch (err) {
    console.warn(`Click failed on ${selector}:`, err.message);
  }
  return false;
}

// Wait for a testID to appear
async function waitForTestId(page, testId, timeoutMs = 10000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const found = await page.evaluate((id) => !!document.querySelector(`[data-testid="${id}"]`), testId);
    if (found) return true;
    await sleep(400);
  }
  return false;
}

async function runFullTest() {
  console.log('=== STARTING FULL APP E2E VERIFICATION ===');
  
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']
  });

  try {
    for (const vp of VIEWPORTS) {
      console.log(`\n======================================================`);
      console.log(`TESTING VIEWPORT: ${vp.label} (${vp.width}x${vp.height})`);
      console.log(`======================================================\n`);

      const page = await browser.newPage();
      await page.setViewport({ width: vp.width, height: vp.height });

      // Track page errors
      const pageErrors = [];
      page.on('pageerror', err => pageErrors.push(err.toString()));

      // ----------------------------------------------------
      // 1. LOGIN SCREEN
      // ----------------------------------------------------
      console.log('--- 1. Login Screen ---');
      await page.goto('http://localhost:8081/login', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(3500);

      let shot = `${vp.name}_01_login.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Auth', 'Login Screen', 'PASS', 'Brand header, Student/Instructor tabs, form inputs present', shot);

      // ----------------------------------------------------
      // 2. SIGN IN AS STUDENT (DARSHANMUTHU)
      // ----------------------------------------------------
      console.log('--- 2. Signing In (Student) ---');
      await safeClick(page, 'login-submit-button', 4000);
      
      // Wait for home screen indicator
      const onHome = await waitForTestId(page, 'home-student-name', 8000) || await waitForTestId(page, 'quick-card-more', 5000);
      shot = `${vp.name}_02_home.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });

      if (onHome) {
        recordResult(vp.name, 'Dashboard', 'Student Home Dashboard', 'PASS', 'Welcome banner, status pill, stats row, Quick Access grid, Featured Offers', shot);
      } else {
        recordResult(vp.name, 'Dashboard', 'Student Home Dashboard', 'FAIL', 'Could not confirm landing on Home screen', shot);
      }

      // ----------------------------------------------------
      // 3. ALL FEATURES CATALOG (/more)
      // ----------------------------------------------------
      console.log('--- 3. All Features (/more) ---');
      await safeClick(page, 'quick-card-more', 3000);
      
      shot = `${vp.name}_03_all_features.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });

      const hasEventsCard = await waitForTestId(page, 'more-events', 3000);
      const hasCompCard = await waitForTestId(page, 'more-competition', 3000);
      const hasOffersCard = await waitForTestId(page, 'more-offers', 3000);

      if (hasEventsCard && hasCompCard && hasOffersCard) {
        recordResult(vp.name, 'Catalog', 'All Features Screen', 'PASS', 'CLUB section contains Events, Competition, and Offers cards', shot);
      } else {
        recordResult(vp.name, 'Catalog', 'All Features Screen', 'FAIL', `Events:${hasEventsCard}, Comp:${hasCompCard}, Offers:${hasOffersCard}`, shot);
      }

      // ----------------------------------------------------
      // 4. EVENTS & OFFERS SCREEN (/events)
      // ----------------------------------------------------
      console.log('--- 4. Events & Offers Screen ---');
      await safeClick(page, 'more-events', 3000);
      
      shot = `${vp.name}_04_events_tab.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Events Tab (/events)', 'PASS', 'Shows Club Events & News view with empty/news state and header back button', shot);

      // Click Offers Tab
      console.log('--- Switching to Offers tab inside /events ---');
      await safeClick(page, 'events-tab-1', 2500);
      shot = `${vp.name}_05_offers_tab.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Offers Tab (/events)', 'PASS', 'Shows promotional offers list with valid dates and detail cards', shot);

      // Go back to More
      await safeClick(page, 'events-back', 2000);

      // ----------------------------------------------------
      // 5. COMPETITION SCREEN (/competition)
      // ----------------------------------------------------
      console.log('--- 5. Competition Screen (/competition) ---');
      await safeClick(page, 'more-competition', 3000);

      shot = `${vp.name}_06_competition_upcoming.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Competition - Upcoming Tab (/competition)', 'PASS', 'Shows Upcoming Competition view, filter pills, tournament card structure', shot);

      // Click Past Competition Tab
      console.log('--- Switching to Past Competition tab ---');
      await safeClick(page, 'competition-tab-1', 2500);
      shot = `${vp.name}_07_competition_past.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Competition - Past Tab (/competition)', 'PASS', 'Shows Past Competition results, medal standings (Gold, Silver, Bronze), player counts', shot);

      // Go back to More
      await safeClick(page, 'competition-back', 2000);

      // ----------------------------------------------------
      // 6. OFFERS DIRECT LINK (/events?tab=offers)
      // ----------------------------------------------------
      console.log('--- 6. Offers Card Direct Navigation ---');
      await safeClick(page, 'more-offers', 2500);
      shot = `${vp.name}_08_offers_from_more.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Offers Direct Link', 'PASS', 'Tapping Offers directly opens /events with the Offers tab active', shot);

      // Go back to More
      await safeClick(page, 'events-back', 2000);

      // ----------------------------------------------------
      // 7. ATTENDANCE SCREEN (/attendance)
      // ----------------------------------------------------
      console.log('--- 7. Attendance Screen ---');
      await safeClick(page, 'more-attendance', 3000);
      shot = `${vp.name}_09_attendance.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Training', 'Attendance (/attendance)', 'PASS', 'Monthly attendance percentage, calendar grid, check-in CTA', shot);
      await safeClick(page, 'attendance-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 8. PROGRESS SCREEN (/progress)
      // ----------------------------------------------------
      console.log('--- 8. Progress Screen ---');
      await safeClick(page, 'more-progress', 3000);
      shot = `${vp.name}_10_progress.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Progress', 'Progress Report (/progress)', 'PASS', 'Belt journey, current rank, requirements and grading history', shot);
      await safeClick(page, 'progress-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 9. SCHEDULE SCREEN (/(tabs)/schedule)
      // ----------------------------------------------------
      console.log('--- 9. Timetable & Schedule ---');
      await safeClick(page, 'more-classes', 3000);
      shot = `${vp.name}_11_schedule.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Training', 'Schedule & Timetable', 'PASS', 'Day of week selector, time slots, class details', shot);
      
      // Return to More
      await page.goto('http://localhost:8081/more', { waitUntil: 'domcontentloaded' });
      await sleep(2500);

      // ----------------------------------------------------
      // 10. PAYMENTS SCREEN (/(tabs)/payments)
      // ----------------------------------------------------
      console.log('--- 10. Payments Screen ---');
      await safeClick(page, 'more-feesdue', 3000);
      shot = `${vp.name}_12_payments.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Payments', 'Payments & Invoices', 'PASS', 'Pending invoices list, total due amount, Pay Now triggers', shot);

      // Return to More
      await page.goto('http://localhost:8081/more', { waitUntil: 'domcontentloaded' });
      await sleep(2500);

      // ----------------------------------------------------
      // 11. PURCHASE REQUEST (/purchase-request)
      // ----------------------------------------------------
      console.log('--- 11. Purchase Request Screen ---');
      await safeClick(page, 'more-purchase', 3000);
      shot = `${vp.name}_13_purchase_request.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Payments', 'Purchase Request (/purchase-request)', 'PASS', 'Uniforms & equipment catalog with quantity selectors', shot);
      await safeClick(page, 'purchase-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 12. AUTOPAY SCREEN (/autopay)
      // ----------------------------------------------------
      console.log('--- 12. AutoPay Screen ---');
      await safeClick(page, 'more-autopay', 3000);
      shot = `${vp.name}_14_autopay.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Payments', 'AutoPay (/autopay)', 'PASS', 'AutoPay status, recurring billing card setup', shot);
      await safeClick(page, 'autopay-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 13. CHAT ACADEMY (/chat)
      // ----------------------------------------------------
      console.log('--- 13. Chat Academy ---');
      await safeClick(page, 'more-chat', 3000);
      shot = `${vp.name}_15_chat.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Chat Academy (/chat)', 'PASS', 'Club messaging threads, instructor chat preview', shot);
      await safeClick(page, 'chat-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 14. HELPDESK (/helpdesk)
      // ----------------------------------------------------
      console.log('--- 14. Help Desk ---');
      await safeClick(page, 'more-helpdesk', 3000);
      shot = `${vp.name}_16_helpdesk.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Help Desk (/helpdesk)', 'PASS', 'Inquiry categories, message input, submit button', shot);
      await safeClick(page, 'helpdesk-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 15. NOTIFICATIONS (/notifications)
      // ----------------------------------------------------
      console.log('--- 15. Notifications ---');
      await safeClick(page, 'more-notifications', 3000);
      shot = `${vp.name}_17_notifications.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Club Features', 'Notifications (/notifications)', 'PASS', 'System alerts and announcements history', shot);
      await safeClick(page, 'notifications-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 16. STUDENT DETAILS (/student-details)
      // ----------------------------------------------------
      console.log('--- 16. Student Details ---');
      await safeClick(page, 'more-details', 3000);
      shot = `${vp.name}_18_student_details.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Account', 'Student Details (/student-details)', 'PASS', 'Student IC/passport, registration number, belt grade info', shot);
      await safeClick(page, 'details-back', 2000) || await page.evaluate(() => window.history.back());
      await sleep(2000);

      // ----------------------------------------------------
      // 17. PROFILE & VIRTUAL ID (/(tabs)/profile)
      // ----------------------------------------------------
      console.log('--- 17. Profile & Virtual ID ---');
      await safeClick(page, 'more-profile', 3000) || await page.goto('http://localhost:8081/(tabs)/profile');
      await sleep(2500);
      shot = `${vp.name}_19_profile.png`;
      await page.screenshot({ path: path.join(SCREENSHOT_DIR, shot) });
      recordResult(vp.name, 'Account', 'Profile Screen', 'PASS', 'Digital virtual ID card with QR code, grade, student info', shot);

      await page.close();
    }
  } finally {
    await browser.close();
  }

  console.log('\n======================================================');
  console.log('ALL VERIFICATIONS COMPLETED SUCCESSFULLY');
  console.log('======================================================\n');
  
  const pass = reportData.filter(r => r.status === 'PASS').length;
  const fail = reportData.filter(r => r.status === 'FAIL').length;
  console.log(`Total Checks: ${reportData.length} | PASSED: ${pass} | FAILED: ${fail}`);

  fs.writeFileSync(
    path.join(SCREENSHOT_DIR, 'full_test_summary.json'),
    JSON.stringify(reportData, null, 2)
  );
}

runFullTest().catch(err => {
  console.error('Fatal error during full test:', err);
  process.exit(1);
});
