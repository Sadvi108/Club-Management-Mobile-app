import '../theme/app_icons.dart';
import 'package:flutter/material.dart';

/// Offline instructions and fictional captures of the current Flutter screens.
/// Routes are coverage metadata, not links: reading a guide never opens a live
/// workflow or requires authentication.
class GuideStep {
  final String key;
  final String category;
  final List<String> routes;
  final IconData icon;
  final String title;
  final String intro;
  final List<GuideDetail> details;
  final List<String> tips;

  /// Highlighted "read this or you will get it wrong" callout.
  final String note;

  /// Asset path of a screenshot of this app, or '' when the page has none.
  final String shot;

  const GuideStep({
    required this.key,
    this.category = 'Student',
    this.routes = const [],
    required this.icon,
    required this.title,
    required this.intro,
    required this.details,
    this.tips = const [],
    this.note = '',
    this.shot = '',
  });
}

class GuideDetail {
  final int n;
  final String title;
  final String text;
  const GuideDetail(this.n, this.title, this.text);
}

const kGuideSteps = <GuideStep>[
  GuideStep(
    key: 'signin',
    routes: ["/login"],
    shot: 'assets/guide/login.png',
    icon: Icons.login,
    title: 'Signing in',
    intro:
        'Your academy issues one account per member. Everything you see in the app — fees, attendance, grading — belongs to that account.',
    details: [
      GuideDetail(1, 'Student or Instructor',
          'Students stay on the Student tab. Instructors switch to Instructor, which also asks for a club code and branch — those come from your academy.'),
      GuideDetail(2, 'Student ID, phone or email',
          'Any one of the three works. If you are not sure what your student ID is, your academy can look it up for you.'),
      GuideDetail(3, 'Password',
          'Tap the eye to check what you typed. Forgot password? explains how to contact your academy. It does not send a reset request; ask the club to reset your password.'),
      GuideDetail(4, 'You stay signed in',
          'The app can restore a valid session on the same build. Installing an update requires sign-in again. Logout in Profile clears the saved session.'),
    ],
    tips: [
      'Not a member yet? Contact your academy at the bottom of this screen — accounts are created by the club, not in the app.',
      'This guide is on the sign-in screen too, so you can read it before you have an account.',
    ],
  ),
  GuideStep(
    key: 'home',
    routes: ["/home"],
    shot: 'assets/guide/home.png',
    icon: AppIcons.home,
    title: 'Your home dashboard',
    intro:
        'Home is the summary of everything that needs your attention today. It refreshes from the club system each time you open it.',
    details: [
      GuideDetail(1, 'Your three headline numbers',
          'Open invoices, your current grade and total amount due. Use the matching shortcuts below to open the details.'),
      GuideDetail(2, 'Shortcut row',
          'Training, Attendance, Timetable, Virtual ID and Profile — the five things members open most, one tap from the top of the screen.'),
      GuideDetail(3, 'Fees due',
          'Pay Now opens the payment screen with your outstanding invoices already listed. A zero balance means no amount is currently due; refresh if you have just made a payment.'),
      GuideDetail(4, 'Today\'s class',
          'Your next session with its time, centre and instructor. Check In jumps straight to the QR scanner.'),
      GuideDetail(5, 'Quick Access + the bell',
          'Shortcuts to every feature, ending in More for the full catalogue. The bell badge counts unread club notifications.'),
    ],
  ),
  GuideStep(
    key: 'checkin',
    routes: ["/attendance"],
    shot: 'assets/guide/attendance.png',
    icon: AppIcons.qr_code_scanner,
    title: 'Checking in with QR',
    intro:
        'Attendance is marked by scanning the QR poster displayed at your training centre. Tap Scan — the round button in the middle of the tab bar — and point your camera at it.',
    details: [
      GuideDetail(1, 'Your attendance rate',
          'Present, absent and total sessions. Ask your academy about its attendance requirements for gradings and events.'),
      GuideDetail(2, 'Scan QR to Check In',
          'Opens the camera. Allow camera access the first time. Hold steady until the code is recognised — you get a clear success or failure message on the spot.'),
      GuideDetail(3, 'If you are asked to pick a class',
          'When a centre runs more than one session at that hour, the app asks which class you are attending. Choose it and the check-in completes.'),
      GuideDetail(4, 'Recent attendance',
          'Every check-in the club has recorded, newest first, with a separate list of classes you missed.'),
    ],
    tips: [
      'Nothing recorded? Check with the front desk that you scanned the current poster — centres reprint them when details change.',
    ],
    note:
        'Scan the centre\'s poster, not your own Virtual ID. The centre code says WHERE you are training; your personal QR is only for identifying yourself at the counter and will be rejected by the check-in scanner.',
  ),
  GuideStep(
    key: 'schedule',
    routes: ["/schedule"],
    shot: 'assets/guide/schedule.png',
    icon: AppIcons.calendar_month,
    title: 'Your timetable',
    intro:
        'Schedule shows the training week for the centres you belong to, so you can see at a glance which days you train.',
    details: [
      GuideDetail(1, 'The week strip',
          'Tap any day to load its sessions. The highlighted day is the one you are viewing.'),
      GuideDetail(2, 'Session cards',
          'Start and end time, the training centre, your instructor and the grade the session is aimed at.'),
      GuideDetail(3, 'Rest days are normal',
          'A day with no sessions shows Rest Day rather than an empty screen — recovery is part of the programme.'),
      GuideDetail(4, 'Book a class',
          'The button in the corner opens booking, covered on the next page.'),
    ],
  ),
  GuideStep(
    key: 'booking',
    routes: ["/book-class"],
    shot: 'assets/guide/book-class.png',
    icon: AppIcons.event_available,
    title: 'Booking a class',
    intro:
        'Booking reserves your place in a session. Work down the screen: centre, then instructor, then month, then the session itself.',
    details: [
      GuideDetail(1, 'Training centre and instructor',
          'Only the centres and instructors you are registered with appear. Changing either reloads the sessions below.'),
      GuideDetail(2, 'Month',
          'Switches which month you are booking into, so you can reserve ahead.'),
      GuideDetail(3, 'Available sessions',
          'Each row is a weekday slot with its time, centre and instructor. Select one, then pick the exact date it runs on.'),
      GuideDetail(4, 'My Bookings',
          'Everything you have reserved, with its status. The app blocks you from booking the same class twice on the same date.'),
    ],
    tips: [
      'Booked by mistake, or plans changed? Tell your academy — cancellations are handled by the club, not in the app.',
    ],
  ),
  GuideStep(
    key: 'payments',
    routes: ["/payments"],
    shot: 'assets/guide/payments.png',
    icon: AppIcons.account_balance_wallet,
    title: 'Fees and payments',
    intro:
        'Everything financial lives under Payments: what you owe now, months you want to settle early, and every receipt you have ever been issued.',
    details: [
      GuideDetail(1, 'Three tabs',
          'Pay is what is outstanding today. Advance Payment settles future months before they are invoiced. History is every past payment and receipt.'),
      GuideDetail(2, 'Who you are paying for',
          'If your family has more than one member at the academy, the name chips let you switch between them and pay each one\'s fees.'),
      GuideDetail(3, 'Pick your invoices',
          'Tick one or several — the running total updates as you go — then tap Pay to open the payment sheet.'),
      GuideDetail(4, 'How you pay',
          'Online card / FPX / e-wallet through the club\'s secure gateway, or Direct Bank-In, where you transfer manually and attach a photo of the slip from your gallery or camera.'),
      GuideDetail(5, 'Receipts',
          'Any receipt in History can be downloaded as an official PDF. There is no automatic monthly payment: every payment is one you make yourself.'),
    ],
    note:
        'A Direct Bank-In payment is not settled the moment you upload the slip — your academy reviews it first, and the invoice stays pending until they approve it.',
  ),
  GuideStep(
    key: 'autopay',
    routes: ["/autopay"],
    shot: 'assets/guide/autopay.png',
    icon: AppIcons.autorenew,
    title: 'Auto Pay reminders',
    intro:
        'Auto Pay is a monthly nudge, not a direct debit. It reminds you when fees are due and opens the payment with the right months already ticked.',
    details: [
      GuideDetail(1, 'Turn it on',
          'One switch. Your phone will ask permission to show notifications the first time — without that the reminder cannot appear, and the screen will tell you so.'),
      GuideDetail(2, 'Pick the day',
          'Any day from the 1st to the 28th. It stops at 28 on purpose so your reminder never lands on a date February does not have.'),
      GuideDetail(3, 'Choose how far ahead',
          'Settle one month at a time, or up to six at once. The current month is not included — it is already invoiced and shows under Fees Due.'),
      GuideDetail(4, 'When the reminder arrives',
          'Tap it and the payment screen opens with those months selected. Check the amount, then pay as normal.'),
    ],
    tips: [
      'Reminders stop the moment you switch Auto Pay off. Nothing is left running in the background.',
      'If your phone misses the reminder — after a restart, say — D-CLIX prompts you the next time you open the app.',
    ],
    note:
        'Your money is never taken automatically. The club system cannot hold a direct debit or keep your card on file, so every payment still needs you to tap Pay. Do not treat Auto Pay as proof your fees are settled — check Fees Due.',
  ),
  GuideStep(
    key: 'notifications',
    routes: ["/notifications"],
    shot: 'assets/guide/notifications.png',
    icon: AppIcons.notifications,
    title: 'Notifications',
    intro:
        'Read fee reminders, class changes and club announcements here. Phone alerts depend on notification permission and background availability.',
    details: [
      GuideDetail(1, 'Unread first',
          'Unread messages are highlighted and counted on the home bell. Tap one to expand the full text — that also marks it read.'),
      GuideDetail(2, 'Mark all read',
          'The double-tick in the header clears the badge in one go.'),
      GuideDetail(3, 'Settings',
          'Open Notification Settings from More to adjust sound, categories and quiet hours. That is the next page.'),
      GuideDetail(4, 'How often it checks',
          'Messages refresh approximately every five seconds while the app is active. Android background checks have a minimum 15-minute interval and can be delayed or stopped by the phone. Instant closed-app push is not available; open the app to check for updates.'),
    ],
  ),
  GuideStep(
    key: 'alerts',
    routes: ["/notification-settings"],
    shot: 'assets/guide/notification-settings.png',
    icon: Icons.tune,
    title: 'Alert settings',
    intro:
        'Control exactly how your phone behaves when the club sends something. Every option here is per-device, so your phone and your tablet can differ.',
    details: [
      GuideDetail(1, 'Sound and vibration',
          'Turn the D-CLIX chime on or off, and whether alerts buzz. Turning both off still delivers the message silently to your tray.'),
      GuideDetail(2, 'Send a test notification',
          'Fires a sample alert immediately so you can hear the sound and confirm alerts are getting through before you rely on them.'),
      GuideDetail(3, 'Choose what alerts you',
          'Mute a whole category — fees, classes or announcements — and keep the rest. A muted category never alerts, though the messages still appear on the Notifications screen.'),
      GuideDetail(4, 'Quiet hours',
          'Silence alerts overnight between the hours you set. Messages remain available in the app. Do not rely on a delayed alert for every message after quiet hours end.'),
    ],
    tips: [
      'If alerts are blocked at the phone level, a warning appears at the top of this screen with a shortcut to your system settings.',
      'Using the app in a web browser? Sound only works after you have clicked the page once — every browser requires that before it will play audio.',
    ],
  ),
  GuideStep(
    key: 'profile',
    routes: ["/profile"],
    shot: 'assets/guide/profile-card.png',
    icon: AppIcons.account_circle,
    title: 'Profile and Virtual ID',
    intro:
        'Your membership card, your details, and the switches for how the app looks and who you are viewing.',
    details: [
      GuideDetail(1, 'Virtual ID',
          'Your personal member QR with your name, grade and registration number. Show it at the counter to identify yourself or claim member offers.'),
      GuideDetail(2, 'Switch student or club',
          'Parents with several children, and members of more than one academy, switch between them here. The whole app follows your selection.'),
      GuideDetail(3, 'Personal info',
          'Your contact details as the club holds them. Use the pencil at the top to update them and change your photo.'),
      GuideDetail(4, 'Appearance and sign-out',
          'Further down are light/dark appearance, support links and Logout. Open this guide from More or the sign-in screen.'),
    ],
    note:
        'The Virtual ID QR identifies you. It is not the check-in code — attendance is only recorded by scanning your centre\'s poster.',
  ),
  GuideStep(
    key: 'chat',
    routes: ["/chat"],
    shot: 'assets/guide/chat.png',
    icon: AppIcons.forum,
    title: 'Chat Academy',
    intro:
        'Chat Academy is the two-way channel to your club: their announcements to you, and your questions back to them.',
    details: [
      GuideDetail(1, 'Help Desk',
          'The pinned conversation at the top. Use it to start a new question with the club admin about anything — fees, schedules, membership.'),
      GuideDetail(2, 'Your conversations',
          'Every message the club has sent, newest first, as a thread you can open and read in full.'),
      GuideDetail(3, 'Replying',
          'Open a thread and send your answer. It reaches the academy\'s admin panel, and they follow up from there.'),
    ],
    tips: [
      'Replies land with the club\'s staff rather than an automated system, so expect a response in their office hours.',
    ],
  ),
  GuideStep(
    key: 'everything',
    routes: ["/more"],
    shot: 'assets/guide/more.png',
    icon: AppIcons.grid_view,
    title: 'Finding everything else',
    intro:
        'More — the last tile in Quick Access — is the full catalogue of every screen in the app, grouped by what it is for.',
    details: [
      GuideDetail(1, 'Training',
          'Your trainer, today\'s classes, the timetable, attendance, booking and the QR scanner.'),
      GuideDetail(2, 'Payments',
          'Fees due, payment history, outstanding invoices, purchase requests and your past purchases.'),
      GuideDetail(3, 'Progress and club',
          'Progress reports, belt and grading, plus events, competitions, offers, chat and the help desk.'),
      GuideDetail(4, 'Account',
          'Profile, student details, edit profile, notification settings and this guide.'),
    ],
    tips: [
      'Instructors get a different set of tabs — Collections, Reports and Settings in place of Schedule, Payments and Profile — and have their own pages in the Instructor section of this guide.',
    ],
  ),
  GuideStep(
    key: "qr-scan",
    category: "Student",
    routes: ["/qr-scan", "/instructor/qr-scan"],
    shot: "assets/guide/qr-scan.png",
    icon: Icons.menu_book_outlined,
    title: "QR attendance scanner",
    intro:
        "Open the round Scan button in the bottom navigation to record your own attendance.",
    details: [
      GuideDetail(1, "Allow the camera",
          "Grant camera access when asked. Keep the centre QR inside the frame; use the torch if the room is dark."),
      GuideDetail(2, "Confirm the class",
          "If more than one training time is available, select the class you are attending."),
      GuideDetail(3, "Check the outcome",
          "Wait for a confirmed check-in, then open Attendance to review the record. A failed or uncertain request is not proof of attendance."),
    ],
    note:
        "Use your training centre QR. Your personal Virtual ID identifies you and cannot check you in. A simulator cannot test a physical camera.",
  ),
  GuideStep(
    key: "training",
    category: "Student",
    routes: ["/training"],
    shot: "assets/guide/training.png",
    icon: Icons.menu_book_outlined,
    title: "Training and your trainer",
    intro:
        "Open Training from Home or More to see your training summary, centres and instructors.",
    details: [
      GuideDetail(1, "Review your activity",
          "Read the attendance-based class count and training summary."),
      GuideDetail(2, "Choose a centre",
          "Select your training centre to load its available training times."),
      GuideDetail(3, "Find the instructor",
          "Review instructor information and use Schedule or Book a Class for the session you need."),
    ],
    note: "",
  ),
  GuideStep(
    key: "advance-payment",
    category: "Student",
    routes: [],
    shot: "assets/guide/advance-payment.png",
    icon: Icons.menu_book_outlined,
    title: "Advance payment",
    intro:
        "Open Payments and choose Advance Payment to request a quote for future months.",
    details: [
      GuideDetail(1, "Select the member",
          "Choose the family member whose fees you want to pay."),
      GuideDetail(2, "Choose months",
          "Select the future months and request the amount. Review the quote before proceeding."),
      GuideDetail(3, "Confirm payment",
          "Tap Pay and complete the offered payment method. Return to History and refresh to check the result."),
    ],
    note:
        "A quote or a return from the payment page is not proof of payment. Payment options depend on the club server and gateway.",
  ),
  GuideStep(
    key: "payment-history",
    category: "Student",
    routes: [],
    shot: "assets/guide/payment-history.png",
    icon: Icons.menu_book_outlined,
    title: "Payment history and receipts",
    intro:
        "Open Payments, then History to review recorded receipts and payment slips.",
    details: [
      GuideDetail(1, "Choose the member",
          "Use the account chips to select the correct student."),
      GuideDetail(2, "Review records",
          "Check receipt dates, amounts and payment status. An uploaded slip can remain pending while the club reviews it."),
      GuideDetail(3, "Open a receipt",
          "Use the PDF action on an available receipt to view, save or share it using your phone’s document controls."),
    ],
    note:
        "If the app says a record type is unavailable, retry later or contact the club; this does not mean there are no payments.",
  ),
  GuideStep(
    key: "invoices",
    category: "Student",
    routes: ["/invoices"],
    shot: "assets/guide/invoices.png",
    icon: Icons.menu_book_outlined,
    title: "Outstanding invoices",
    intro:
        "Open Outstanding Invoices from More to review fees still listed as unpaid.",
    details: [
      GuideDetail(1, "Review the list",
          "Check the invoice number, description, date and amount."),
      GuideDetail(2, "Refresh after payment",
          "Pull down to fetch the current club records."),
      GuideDetail(3, "Pay or resolve a mismatch",
          "Use Payments to settle fees. Contact your academy if a confirmed payment is still outstanding."),
    ],
    note: "",
  ),
  GuideStep(
    key: "progress",
    category: "Student",
    routes: ["/progress"],
    shot: "assets/guide/progress.png",
    icon: Icons.menu_book_outlined,
    title: "Progress, belt and grading",
    intro: "Open Progress Report or Belt / Rank from Quick Access or More.",
    details: [
      GuideDetail(1, "Review your grade",
          "Check the current grade and recorded progress."),
      GuideDetail(2, "Read grading information",
          "Review the grading entries, centre and dates available for your account."),
      GuideDetail(3, "Confirm eligibility",
          "Ask your instructor about the next grading and any requirements; the app only displays the club’s records."),
    ],
    note: "",
  ),
  GuideStep(
    key: "events",
    category: "Student",
    routes: ["/events"],
    shot: "assets/guide/events.png",
    icon: Icons.menu_book_outlined,
    title: "Events and club news",
    intro:
        "Open Events from More to see club news and switch to the Offers tab.",
    details: [
      GuideDetail(
          1, "Read events", "Review the club’s published updates and dates."),
      GuideDetail(2, "Check offers",
          "Switch to Offers and open an offer to read its conditions."),
      GuideDetail(3, "Refresh updates",
          "Pull down to load current content. Confirm attendance or registration arrangements with the club."),
    ],
    note: "",
  ),
  GuideStep(
    key: "offers",
    category: "Student",
    routes: ["/offers"],
    shot: "assets/guide/offers.png",
    icon: Icons.menu_book_outlined,
    title: "Member offers",
    intro: "Open Offers to browse benefits published by your academy.",
    details: [
      GuideDetail(
          1, "Browse offers", "Review the offer title and expiry date."),
      GuideDetail(2, "Open details",
          "Tap an offer to read its terms and member identification requirements."),
      GuideDetail(3, "Claim with the club",
          "Show the offer and your Virtual ID when requested. The club confirms eligibility."),
    ],
    note: "",
  ),
  GuideStep(
    key: "offer-detail",
    category: "Student",
    routes: ["/offer/:code"],
    shot: "assets/guide/offer-detail.png",
    icon: Icons.menu_book_outlined,
    title: "Offer details",
    intro: "Open an offer from the offers list to see its full description.",
    details: [
      GuideDetail(1, "Read the conditions",
          "Check validity dates, eligible products or services, and any restrictions."),
      GuideDetail(2, "Show your membership",
          "Present the offer and member QR at the counter if required."),
      GuideDetail(3, "Confirm redemption",
          "Ask the club to confirm the benefit; opening this page does not itself redeem an offer."),
    ],
    note: "",
  ),
  GuideStep(
    key: "competition",
    category: "Student",
    routes: ["/competition"],
    shot: "assets/guide/competition.png",
    icon: Icons.menu_book_outlined,
    title: "Competitions",
    intro: "Open Competition from More to review tournament information.",
    details: [
      GuideDetail(1, "Review available events",
          "Read event names, centres, dates and status."),
      GuideDetail(2, "Check past and upcoming events",
          "Use the available views to distinguish previous results from scheduled events."),
      GuideDetail(3, "Arrange participation",
          "Contact your instructor for entry requirements and registration. Viewing an event does not register you."),
    ],
    note: "",
  ),
  GuideStep(
    key: "student-details",
    category: "Student",
    routes: ["/student-details"],
    shot: "assets/guide/student-details.png",
    icon: Icons.menu_book_outlined,
    title: "Student details",
    intro:
        "Open Student Details from More or Profile for the information the academy holds about you.",
    details: [
      GuideDetail(
          1, "Check identity", "Review your name, registration and grade."),
      GuideDetail(2, "Review training details",
          "Check the centre, instructor and training time."),
      GuideDetail(3, "Correct information",
          "Use Edit Profile for fields you can change; ask the club to correct controlled membership or grading records."),
    ],
    note: "",
  ),
  GuideStep(
    key: "edit-profile",
    category: "Student",
    routes: ["/edit-profile"],
    shot: "assets/guide/edit-profile.png",
    icon: Icons.menu_book_outlined,
    title: "Edit profile and photo",
    intro: "Tap the pencil in Profile or open Edit Profile from More.",
    details: [
      GuideDetail(1, "Review editable fields",
          "Update only the contact or personal information shown in the form."),
      GuideDetail(2, "Change the photo",
          "Choose a photo from your gallery or camera and grant access when asked."),
      GuideDetail(3, "Save and verify",
          "Tap Save, wait for confirmation, then return to Profile and review the result."),
    ],
    note:
        "Some photos may be kept only on this device when the backend cannot save them. Membership, grade and club changes may require the academy.",
  ),
  GuideStep(
    key: "chat-thread",
    category: "Student",
    routes: ["/notification/:groupId"],
    shot: "assets/guide/chat-thread.png",
    icon: Icons.menu_book_outlined,
    title: "Read and reply to a conversation",
    intro:
        "Open a conversation in Chat Academy to read messages and reply to the club.",
    details: [
      GuideDetail(1, "Read the thread",
          "Incoming messages belong to your signed-in account. The view refreshes while the app is active."),
      GuideDetail(2, "Compose a reply",
          "Type your message and tap Send once. Keep the app open until the result appears."),
      GuideDetail(3, "Check delivery state",
          "A failed send is not delivered. Retry only after checking the result; your outgoing history is stored on this device."),
    ],
    note:
        "The server does not provide outgoing message history to this app. Reinstalling or changing devices can remove local replies. Staff respond during their working hours.",
  ),
  GuideStep(
    key: "helpdesk",
    category: "Student",
    routes: ["/helpdesk"],
    shot: "assets/guide/helpdesk.png",
    icon: Icons.menu_book_outlined,
    title: "Help Desk",
    intro:
        "Open Help Desk from Profile or More when you need help from the academy.",
    details: [
      GuideDetail(1, "Choose the subject",
          "Describe the fee, training or membership issue clearly."),
      GuideDetail(2, "Write your message",
          "Include the relevant class or invoice reference without sharing your password."),
      GuideDetail(3, "Submit and follow up",
          "Send once and wait for confirmation. Check Chat Academy for staff replies."),
    ],
    note: "",
  ),
  GuideStep(
    key: "purchases",
    category: "Student",
    routes: ["/purchases"],
    shot: "assets/guide/purchases.png",
    icon: Icons.menu_book_outlined,
    title: "My purchases",
    intro:
        "Open My Purchases from Profile or More to review club purchase records.",
    details: [
      GuideDetail(1, "Review products",
          "Check the item, date, quantity or amount shown in each record."),
      GuideDetail(2, "Check status",
          "Distinguish pending requests from purchases or collections already recorded."),
      GuideDetail(3, "Ask about fulfilment",
          "Contact the academy to arrange collection or resolve an incorrect record."),
    ],
    note: "",
  ),
  GuideStep(
    key: "purchase-request",
    category: "Student",
    routes: ["/purchase-request"],
    shot: "assets/guide/purchase-request.png",
    icon: Icons.menu_book_outlined,
    title: "Request products",
    intro:
        "Open Purchase Request from Quick Access or More to request uniforms or club equipment.",
    details: [
      GuideDetail(1, "Choose products",
          "Select the item and quantity from the club catalogue."),
      GuideDetail(2, "Review the request",
          "Check all items and the displayed amounts before submitting."),
      GuideDetail(3, "Send the request",
          "Submit once and wait for confirmation. Review the request status with your club."),
    ],
    note: "A purchase request is not proof of payment or product collection.",
  ),
  GuideStep(
    key: "instructor-home",
    category: "Instructor",
    routes: ["/instructor/home"],
    shot: "assets/guide/instructor-home.png",
    icon: Icons.menu_book_outlined,
    title: "Instructor dashboard",
    intro:
        "Sign in as Instructor using the club code, user ID, password and branch supplied by your academy.",
    details: [
      GuideDetail(1, "Check your branch",
          "Confirm the academy and active branch in the header."),
      GuideDetail(2, "Open shortcuts",
          "Use the dashboard shortcuts for students, attendance, collections and reports."),
      GuideDetail(3, "Review updates",
          "Check the bell for messages and refresh current summaries before acting."),
    ],
    note: "",
  ),
  GuideStep(
    key: "instructor-attendance",
    category: "Instructor",
    routes: ["/instructor/attendance"],
    shot: "assets/guide/instructor-attendance.png",
    icon: Icons.menu_book_outlined,
    title: "Class lists and centre QR",
    intro:
        "Open Attendance in the instructor tools to select a centre and display its attendance QR.",
    details: [
      GuideDetail(1, "Select a centre",
          "Choose the training centre, then select the relevant training time."),
      GuideDetail(2, "Review the class",
          "Read the student list and confirm you selected the intended centre."),
      GuideDetail(3, "Display or print the QR",
          "Use Show QR or the print action to provide the centre code to students. Students scan it from their own signed-in account."),
    ],
    note:
        "This screen cannot mark another student present by calling the personal check-in endpoint. Review recorded attendance in Attendance Report.",
  ),
  GuideStep(
    key: "instructor-collections",
    category: "Instructor",
    routes: ["/instructor/collections"],
    shot: "assets/guide/instructor-collections.png",
    icon: Icons.menu_book_outlined,
    title: "Collections",
    intro:
        "Open Collections to review payment totals and the supporting records.",
    details: [
      GuideDetail(1, "Choose a collection category",
          "Open cash, online or bank-in records from the available cards."),
      GuideDetail(2, "Review records",
          "Check member names, amounts, references and recorded status."),
      GuideDetail(3, "Refresh the totals",
          "Refresh after the club confirms a payment. A count alone does not confirm an individual invoice was settled."),
    ],
    note: "",
  ),
  GuideStep(
    key: "instructor-reports",
    category: "Instructor",
    routes: ["/instructor/reports"],
    shot: "assets/guide/instructor-reports.png",
    icon: Icons.menu_book_outlined,
    title: "Finding instructor reports",
    intro:
        "Open Reports in the bottom navigation for the full instructor report catalogue.",
    details: [
      GuideDetail(1, "Pick the report",
          "Choose the student, training, attendance, finance or event report you need."),
      GuideDetail(2, "Set available filters",
          "Use the controls offered by that report to narrow the records."),
      GuideDetail(3, "Read report instructions",
          "Use the following guide pages for each report, including its limitations."),
    ],
    note: "",
  ),
  GuideStep(
    key: "instructor-settings",
    category: "Instructor",
    routes: ["/instructor/settings"],
    shot: "assets/guide/instructor-settings.png",
    icon: Icons.menu_book_outlined,
    title: "Instructor settings and branch",
    intro:
        "Open Settings to review your instructor account and device preferences.",
    details: [
      GuideDetail(1, "Review your profile",
          "Open your profile card to check the club and instructor details."),
      GuideDetail(2, "Switch branch",
          "Choose a branch when available and wait for the account data to reload."),
      GuideDetail(3, "Adjust preferences or sign out",
          "Change appearance and notification preferences, open User Guide, or log out before lending your device."),
    ],
    note: "",
  ),
  GuideStep(
    key: "instructor-student-detail",
    category: "Instructor",
    routes: ["/instructor/student-detail"],
    shot: "assets/guide/instructor-student-detail.png",
    icon: Icons.menu_book_outlined,
    title: "Student account details",
    intro: "Open a student from the Student List report.",
    details: [
      GuideDetail(1, "Confirm the student",
          "Check name and registration before reviewing financial records."),
      GuideDetail(2, "Read the summary",
          "Review outstanding invoices and recent receipts for this student."),
      GuideDetail(3, "Resolve discrepancies",
          "Refresh the records and contact the club administrator for corrections."),
    ],
    note: "",
  ),
  GuideStep(
    key: "student-particulars",
    category: "Instructor",
    routes: ["/instructor/student-particulars/:id"],
    shot: "assets/guide/student-particulars.png",
    icon: Icons.menu_book_outlined,
    title: "Student particulars",
    intro:
        "Open an online submission from Reports → New Student to review the applicant’s particulars.",
    details: [
      GuideDetail(1, "Confirm identity",
          "Verify the selected applicant and submitted identity details."),
      GuideDetail(2, "Review details",
          "When available, confirm the training centre, student centre, grade and fee type before approval."),
      GuideDetail(3, "Request corrections",
          "Approve or reject only after checking the submission. If Awaiting backend appears, the club must enable this service first."),
    ],
    note: "",
  ),
  GuideStep(
    key: "new-student",
    category: "Instructor",
    routes: ["/instructor/reports/new-student"],
    shot: "assets/guide/new-student.png",
    icon: Icons.menu_book_outlined,
    title: "New student approvals",
    intro:
        "Open Reports, then New Student to review online submissions when enabled by your club.",
    details: [
      GuideDetail(1, "Check availability",
          "If Awaiting backend appears, your club has not enabled the submission service. Retry after the club confirms availability."),
      GuideDetail(2, "Review a submission",
          "When available, open the applicant and confirm the training centre, student centre, grade and fee type."),
      GuideDetail(3, "Decide carefully",
          "Approve or reject only after checking the details and wait for server confirmation."),
    ],
    note:
        "Online approvals are currently unavailable on the deployed server. This page shows that limitation instead of claiming that a student was created.",
  ),
  GuideStep(
    key: "report-student-centers",
    category: "Instructor reports",
    routes: ["/instructor/reports/student-centers"],
    shot: "assets/guide/report-student-centers.png",
    icon: Icons.menu_book_outlined,
    title: "Student Centers",
    intro:
        "Use this instructor report to review student centers records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Student Centers."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-training-centers",
    category: "Instructor reports",
    routes: ["/instructor/reports/training-centers"],
    shot: "assets/guide/report-training-centers.png",
    icon: Icons.menu_book_outlined,
    title: "Training Centers",
    intro:
        "Use this instructor report to review training centers records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Training Centers."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-exam-centers",
    category: "Instructor reports",
    routes: ["/instructor/reports/exam-centers"],
    shot: "assets/guide/report-exam-centers.png",
    icon: Icons.menu_book_outlined,
    title: "Exam Centers",
    intro:
        "Use this instructor report to review exam centers records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Exam Centers."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-student-list",
    category: "Instructor reports",
    routes: ["/instructor/reports/student-list"],
    shot: "assets/guide/report-student-list.png",
    icon: Icons.menu_book_outlined,
    title: "Student List",
    intro:
        "Use this instructor report to review student list records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Student List."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Open a student",
          "Tap the student row to review their account details, outstanding invoices and receipts."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-training-time",
    category: "Instructor reports",
    routes: ["/instructor/reports/training-time"],
    shot: "assets/guide/report-training-time.png",
    icon: Icons.menu_book_outlined,
    title: "Training Time",
    intro:
        "Use this instructor report to review training time records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Training Time."),
      GuideDetail(2, "Select the centre",
          "Choose a training centre first; its training times then load below."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-grading-schedule",
    category: "Instructor reports",
    routes: ["/instructor/reports/grading-schedule"],
    shot: "assets/guide/report-grading-schedule.png",
    icon: Icons.menu_book_outlined,
    title: "Grading Schedule",
    intro:
        "Use this instructor report to review grading schedule records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Grading Schedule."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note:
        "These views use the club grading schedule records. Check dates to distinguish past and future events.",
  ),
  GuideStep(
    key: "report-outstanding",
    category: "Instructor reports",
    routes: ["/instructor/reports/outstanding"],
    shot: "assets/guide/report-outstanding.png",
    icon: Icons.menu_book_outlined,
    title: "Outstanding Report",
    intro:
        "Use this instructor report to review outstanding report records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Outstanding Report."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-attendance",
    category: "Instructor reports",
    routes: ["/instructor/reports/attendance"],
    shot: "assets/guide/report-attendance.png",
    icon: Icons.menu_book_outlined,
    title: "Attendance Report",
    intro:
        "Use this instructor report to review attendance report records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Attendance Report."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-receipt",
    category: "Instructor reports",
    routes: ["/instructor/reports/receipt"],
    shot: "assets/guide/report-receipt.png",
    icon: Icons.menu_book_outlined,
    title: "Receipt",
    intro:
        "Use this instructor report to review receipt records from your club.",
    details: [
      GuideDetail(1, "Open the report", "Go to Reports and choose Receipt."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-grading-past",
    category: "Instructor reports",
    routes: ["/instructor/reports/grading-past"],
    shot: "assets/guide/report-grading-past.png",
    icon: Icons.menu_book_outlined,
    title: "Grading Past",
    intro:
        "Use this instructor report to review grading past records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Grading Past."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note:
        "These views use the club grading schedule records. Check dates to distinguish past and future events.",
  ),
  GuideStep(
    key: "report-purchase-request",
    category: "Instructor reports",
    routes: ["/instructor/reports/purchase-request"],
    shot: "assets/guide/report-purchase-request.png",
    icon: Icons.menu_book_outlined,
    title: "Purchase Request",
    intro:
        "Use this instructor report to review purchase request records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Purchase Request."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-tournament",
    category: "Instructor reports",
    routes: ["/instructor/reports/tournament"],
    shot: "assets/guide/report-tournament.png",
    icon: Icons.menu_book_outlined,
    title: "Tournament Schedule",
    intro:
        "Use this instructor report to review tournament schedule records from your club.",
    details: [
      GuideDetail(1, "Open the report",
          "Go to Reports and choose Tournament Schedule."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-missing-invoice",
    category: "Instructor reports",
    routes: ["/instructor/reports/missing-invoice"],
    shot: "assets/guide/report-missing-invoice.png",
    icon: Icons.menu_book_outlined,
    title: "Missing Invoice",
    intro:
        "Use this instructor report to review missing invoice records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Missing Invoice."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note:
        "This screen currently reads outstanding invoices. It cannot prove that a missing invoice was generated or identify every unbilled member; confirm those cases in the club admin system.",
  ),
  GuideStep(
    key: "report-fee-master",
    category: "Instructor reports",
    routes: ["/instructor/reports/fee-master"],
    shot: "assets/guide/report-fee-master.png",
    icon: Icons.menu_book_outlined,
    title: "Invoice Types",
    intro:
        "Use this instructor report to review invoice types records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Invoice Types."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note:
        "This is a read-only invoice-type list. Pricing or fee setup changes must be made by the club administrator.",
  ),
  GuideStep(
    key: "report-payment-slip",
    category: "Instructor reports",
    routes: ["/instructor/reports/payment-slip"],
    shot: "assets/guide/report-payment-slip.png",
    icon: Icons.menu_book_outlined,
    title: "Payment Slip",
    intro:
        "Use this instructor report to review payment slip records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Payment Slip."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-reimbursement",
    category: "Instructor reports",
    routes: ["/instructor/reports/reimbursement"],
    shot: "assets/guide/report-reimbursement.png",
    icon: Icons.menu_book_outlined,
    title: "Reimbursement",
    intro:
        "Use this instructor report to review reimbursement records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Reimbursement."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-contribution",
    category: "Instructor reports",
    routes: ["/instructor/reports/contribution"],
    shot: "assets/guide/report-contribution.png",
    icon: Icons.menu_book_outlined,
    title: "Contribution",
    intro:
        "Use this instructor report to review contribution records from your club.",
    details: [
      GuideDetail(
          1, "Open the report", "Go to Reports and choose Contribution."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-activity",
    category: "Instructor reports",
    routes: ["/instructor/reports/activity"],
    shot: "assets/guide/report-activity.png",
    icon: Icons.menu_book_outlined,
    title: "Activities",
    intro:
        "Use this instructor report to review activities records from your club.",
    details: [
      GuideDetail(1, "Open the report", "Go to Reports and choose Activities."),
      GuideDetail(2, "Narrow the records",
          "Use the search, centre, status or date controls shown on this report. Change only the filters available on this screen, then apply or refresh."),
      GuideDetail(3, "Review the result",
          "Check the member, reference, date and status fields shown. No records applies only to the selected filters; an error means the data could not be loaded."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-tournament-past",
    category: "Instructor reports",
    routes: ["/instructor/reports/tournament-past"],
    shot: "assets/guide/report-tournament-past.png",
    icon: Icons.menu_book_outlined,
    title: "Past tournaments",
    intro: "Open the tournament view from Reports.",
    details: [
      GuideDetail(1, "Review the dates",
          "Check the date and status of each listed tournament."),
      GuideDetail(2, "Read the event information",
          "Review the available venue, grade or participation information."),
      GuideDetail(3, "Confirm with the club",
          "Ask the organiser about registration or final results; viewing this page does not submit an entry."),
    ],
    note: "",
  ),
  GuideStep(
    key: "report-tournament-upcoming",
    category: "Instructor reports",
    routes: ["/instructor/reports/tournament-upcoming"],
    shot: "assets/guide/report-tournament-upcoming.png",
    icon: Icons.menu_book_outlined,
    title: "Upcoming tournaments",
    intro: "Open the tournament view from Reports.",
    details: [
      GuideDetail(1, "Review the dates",
          "Check the date and status of each listed tournament."),
      GuideDetail(2, "Read the event information",
          "Review the available venue, grade or participation information."),
      GuideDetail(3, "Confirm with the club",
          "Ask the organiser about registration or final results; viewing this page does not submit an entry."),
    ],
    note: "",
  ),
  GuideStep(
    key: 'collection-list',
    category: 'Instructor',
    routes: ['/instructor/collections/:typeId'],
    shot: 'assets/guide/collection-list.png',
    icon: Icons.receipt_long,
    title: 'Collection records',
    intro:
        'Open a payment category from Instructor Collections to review its records.',
    details: [
      GuideDetail(1, 'Choose a category',
          'Open Cash Payments, Online Payments or Payment Slips from Collections.'),
      GuideDetail(2, 'Review the records',
          'Check each member, reference, amount and status. Use the available search or date controls to narrow the list.'),
      GuideDetail(3, 'Confirm the result',
          'Refresh after the club confirms a payment. An uploaded slip can remain pending until the academy approves it.'),
    ],
  ),
];
