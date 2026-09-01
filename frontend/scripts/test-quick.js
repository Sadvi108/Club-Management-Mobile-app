const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SCREENSHOT_DIR = 'C:\\Users\\User\\.gemini\\antigravity-ide\\brain\\71f3209a-414d-4e63-8af6-ef98beea299c\\test_screenshots';

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

async function runQuickCheck() {
  console.log('Launching Chrome...');
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu']
  });

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844 });
    console.log('Navigating to http://localhost:8081...');
    await page.goto('http://localhost:8081', { waitUntil: 'domcontentloaded', timeout: 30000 });
    
    // wait 4 seconds for Expo to mount React Native components
    await new Promise(r => setTimeout(r, 4000));
    
    const screenshotPath = path.join(SCREENSHOT_DIR, 'quick_check_mobile.png');
    await page.screenshot({ path: screenshotPath });
    console.log('Screenshot saved to:', screenshotPath);
    console.log('Page title:', await page.title());
    const content = await page.content();
    console.log('Content length:', content.length);
  } finally {
    await browser.close();
  }
}

runQuickCheck().catch(err => {
  console.error('Quick check failed:', err);
  process.exit(1);
});
