import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/tabs_shell.dart';
import '../screens/home_screen.dart';
import '../screens/training_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/events_screen.dart';
import '../screens/qr_scan_screen.dart';
import '../screens/notification_detail_screen.dart';
import '../screens/instructor_tabs_shell.dart';
import '../screens/instructor_home_screen.dart';
import '../screens/instructor_collections_screen.dart';
import '../screens/instructor_reports_screen.dart';
import '../screens/instructor_settings_screen.dart';
import '../screens/instructor_report_list_screen.dart';
import '../services/api.dart';
import '../services/user_session.dart';

GoRoute _reportRoute(String path, String title, ReportFetcher fetcher) =>
    GoRoute(
      path: path,
      builder: (_, __) =>
          InstructorReportListScreen(title: title, fetcher: fetcher),
    );

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (loc.startsWith('/instructor') && !UserSession.instance.isInstructor) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) =>
          TabsShell(child: child, location: state.matchedLocation),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
        GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
        GoRoute(path: '/payments', builder: (_, __) => const PaymentsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => InstructorTabsShell(
        child: child,
        location: state.matchedLocation,
      ),
      routes: [
        GoRoute(
            path: '/instructor/home',
            builder: (_, __) => const InstructorHomeScreen()),
        GoRoute(
            path: '/instructor/collections',
            builder: (_, __) => const InstructorCollectionsScreen()),
        GoRoute(
            path: '/instructor/reports',
            builder: (_, __) => const InstructorReportsScreen()),
        GoRoute(
            path: '/instructor/settings',
            builder: (_, __) => const InstructorSettingsScreen()),
      ],
    ),
    // Drill-down report routes (outside the shell so they appear full-screen
    // with their own back button).
    _reportRoute('/instructor/reports/student-centers', 'Student Centers',
        Api.reportsStudentCenters),
    _reportRoute('/instructor/reports/training-centers', 'Training Centers',
        Api.reportsTrainingCenters),
    _reportRoute('/instructor/reports/exam-centers', 'Exam Centers',
        Api.reportsExamCenters),
    _reportRoute('/instructor/reports/student-list', 'Student List',
        Api.reportsStudentDetails),
    _reportRoute('/instructor/reports/training-time', 'Training Time',
        Api.listingTrainingCenters),
    _reportRoute('/instructor/reports/grading-schedule', 'Grading Schedule',
        Api.reportsGradingSchedule),
    _reportRoute('/instructor/reports/outstanding', 'Outstanding Report',
        Api.outstandingFetch),
    _reportRoute('/instructor/reports/attendance', 'Attendance Report',
        Api.reportsAttendance),
    _reportRoute('/instructor/reports/receipt', 'Receipt',
        Api.reportsReceipts),
    _reportRoute('/instructor/reports/grading-past', 'Grading Past',
        Api.reportsGradingSchedule),
    _reportRoute('/instructor/reports/purchase-request', 'Purchase Request',
        Api.reportsPurchaseRequests),
    _reportRoute('/instructor/reports/activity', 'Activities',
        Api.reportsActivity),
    _reportRoute('/instructor/reports/tournament', 'Tournament Schedule',
        Api.reportsTournamentSummary),
    _reportRoute('/instructor/reports/missing-invoice', 'Missing Invoice',
        Api.outstandingFetch),
    _reportRoute('/instructor/reports/fee-master', 'Fee Master',
        Api.listingInvoceTypes),
    _reportRoute('/instructor/reports/new-student', 'New Student',
        Api.reportsStudentDetails),
    _reportRoute('/instructor/reports/payment-slip', 'Payment Slip',
        Api.reportsPaymentSlips),
    _reportRoute('/instructor/reports/reimbursement', 'Reimbursement',
        Api.reportsReimbursement),
    GoRoute(
      path: '/instructor/qr-scan',
      pageBuilder: (_, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const QRScanScreen(),
      ),
    ),
    GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
    GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
    GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
    GoRoute(
      path: '/notification/:groupId',
      builder: (_, state) => NotificationDetailScreen(
        groupId: state.pathParameters['groupId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/qr-scan',
      pageBuilder: (_, state) => MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: const QRScanScreen(),
      ),
    ),
  ],
);
