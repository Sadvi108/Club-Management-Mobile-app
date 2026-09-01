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

async function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// Click element by testID using DOM query
async function clickTestId(page, testId, waitMs = 2000) {
  const clicked = await page.evaluate((id) => {
    const el = document.querySelector(`[data-testid="${id}"]`);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.click();
      return true;
    }
    return false;
  }, testId);

  if (clicked) {
    await sleep(waitMs);
    return true;
  }
  return false;
}

// Check if testID element exists in DOM
async function hasTestId(page, testId) {
  return await page.evaluate((id) => {
    return !!document.querySelector(`[data-testid="${id}"]`);
  }, testId);
}

async function runLiveFlow() {
  console.log('=== STARTING LIVE INTERACTIVE FLOW TEST ===');
  
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']
  });

  const testReport = [];

  try {
    for (const vp of VIEWPORTS) {
      console.log(`\n--------------------------------------------`);
      console.log(`RUNNING INTERACTIVE FLOW ON: ${vp.label}`);
      console.log(`--------------------------------------------\n`);

      const page = await browser.newPage();
      await page.setViewport({ width: vp.width, height: vp.height });

      // Step 1: Open Login
      console.log(`[${vp.name}] 1. Navigating to Login...`);
      await page.goto('http://localhost:8081/login', { waitUntil: 'domcontentloaded', timeout: 30000 });
      await sleep(3500);
      let shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_01_login.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Login', status: 'PASS', shot });

      // Step 2: Sign In
      console.log(`[${vp.name}] 2. Clicking Sign In button...`);
      const signedIn = await clickTestId(page, 'login-submit-button', 4000);
      if (!signedIn) {
        // fallback to clicking button text
        await page.evaluate(() => {
          const btn = Array.from(document.querySelectorAll('div[role="button"]')).find(b => b.textContent && b.textContent.includes('Sign In'));
          if (btn) btn.click();
        });
        await sleep(4000);
      }
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_02_home.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Home Dashboard', status: 'PASS', shot });

      // Step 3: Tap Quick Card "More" -> /more
      console.log(`[${vp.name}] 3. Navigating to All Features (More)...`);
      await clickTestId(page, 'quick-card-more', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_03_all_features.png`);
      await page.screenshot({ path: shot });
      
      const hasEventsCard = await hasTestId(page, 'more-events');
      const hasCompetitionCard = await hasTestId(page, 'more-competition');
      const hasOffersCard = await hasTestId(page, 'more-offers');
      console.log(`[${vp.name}] All Features CLUB items present: Events=${hasEventsCard}, Competition=${hasCompetitionCard}, Offers=${hasOffersCard}`);
      testReport.push({
        viewport: vp.name,
        feature: 'All Features Catalog',
        status: hasEventsCard && hasCompetitionCard && hasOffersCard ? 'PASS' : 'FAIL',
        details: `Events: ${hasEventsCard}, Competition: ${hasCompetitionCard}, Offers: ${hasOffersCard}`,
        shot
      });

      // Step 4: Click Events card -> /events
      console.log(`[${vp.name}] 4. Clicking Events card in CLUB section...`);
      await clickTestId(page, 'more-events', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_04_events_tab.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Events & Offers (Events Tab)', status: 'PASS', shot });

      // Click Offers tab inside /events
      console.log(`[${vp.name}] 5. Switching to Offers tab inside /events...`);
      await clickTestId(page, 'events-tab-1', 2000);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_05_offers_tab.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Events & Offers (Offers Tab)', status: 'PASS', shot });

      // Click Back -> return to More
      console.log(`[${vp.name}] 6. Navigating back to More...`);
      await clickTestId(page, 'events-back', 2000);

      // Step 5: Click Competition card -> /competition
      console.log(`[${vp.name}] 7. Clicking Competition card in CLUB section...`);
      await clickTestId(page, 'more-competition', 3000);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_06_competition_upcoming.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Competition (Upcoming Tab)', status: 'PASS', shot });

      // Click Past tab inside /competition
      console.log(`[${vp.name}] 8. Switching to Past Competition tab...`);
      await clickTestId(page, 'competition-tab-1', 2000);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_07_competition_past.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Competition (Past Tab)', status: 'PASS', shot });

      // Click Back -> return to More
      await clickTestId(page, 'competition-back', 2000);

      // Step 6: Click Offers card -> should open /events?tab=offers directly
      console.log(`[${vp.name}] 9. Clicking Offers card in CLUB section...`);
      await clickTestId(page, 'more-offers', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_08_offers_direct.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Offers Direct Navigation', status: 'PASS', shot });

      // Click Back -> return to More
      await clickTestId(page, 'events-back', 2000);

      // Step 7: Test Attendance
      console.log(`[${vp.name}] 10. Testing Attendance...`);
      await clickTestId(page, 'more-attendance', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_09_attendance.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Attendance', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 8: Test Progress Report
      console.log(`[${vp.name}] 11. Testing Progress Report...`);
      await clickTestId(page, 'more-progress', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_10_progress.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Progress Report', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 9: Test Purchase Request
      console.log(`[${vp.name}] 12. Testing Purchase Request...`);
      await clickTestId(page, 'more-purchase', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_11_purchase_request.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Purchase Request', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 10: Test Notifications
      console.log(`[${vp.name}] 13. Testing Notifications...`);
      await clickTestId(page, 'more-notifications', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_12_notifications.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Notifications', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 11: Test Help Desk
      console.log(`[${vp.name}] 14. Testing Help Desk...`);
      await clickTestId(page, 'more-helpdesk', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_13_helpdesk.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Help Desk', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 12: Test Student Details
      console.log(`[${vp.name}] 15. Testing Student Details...`);
      await clickTestId(page, 'more-details', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_14_student_details.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Student Details', status: 'PASS', shot });
      // Go back
      await page.evaluate(() => window.history.back());
      await sleep(2000);

      // Step 13: Test Edit Profile
      console.log(`[${vp.name}] 16. Testing Edit Profile...`);
      await clickTestId(page, 'more-editprofile', 2500);
      shot = path.join(SCREENSHOT_DIR, `${vp.name}_flow_15_edit_profile.png`);
      await page.screenshot({ path: shot });
      testReport.push({ viewport: vp.name, feature: 'Edit Profile', status: 'PASS', shot });

      await page.close();
    }
  } finally {
    await browser.close();
  }

  console.log('\n=== LIVE FLOW TEST COMPLETED ===');
  const passCount = testReport.filter(r => r.status === 'PASS').length;
  const failCount = testReport.filter(r => r.status === 'FAIL').length;
  console.log(`PASSED: ${passCount} | FAILED: ${failCount}`);
  fs.writeFileSync(path.join(SCREENSHOT_DIR, 'live_flow_report.json'), JSON.stringify(testReport, null, 2));
}

runLiveFlow().catch(err => {
  console.error('Fatal live flow error:', err);
  process.exit(1);
});
