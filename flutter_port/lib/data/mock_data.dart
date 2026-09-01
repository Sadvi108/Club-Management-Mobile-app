import 'package:flutter/material.dart';
import '../models/models.dart';

const kStudent = Student(
  id: 'SA-2026-0142',
  name: 'Aarav Sharma',
  membership: 'Gold Member',
  belt: 'Blue Belt',
  beltColor: Color(0xFF3B82F6),
  level: 'Intermediate II',
  joinDate: 'Jan 2024',
  photo: 'https://i.pravatar.cc/200?img=15',
  phone: '+60 12-345 6789',
  email: 'aarav.sharma@email.com',
  parent: Parent(name: 'Rohan Sharma', phone: '+60 12-811 2233', relation: 'Emergency Contact'),
  attendance: 87,
  fitness: 82,
  nextPayment: NextPayment(amount: 480, dueDate: '28 Feb 2026', label: 'Monthly Membership'),
);

const kQuickCards = <QuickCard>[
  QuickCard('attendance', 'Attendance', Icons.check_circle_outline, Color(0xFF10B981), '/attendance'),
  QuickCard('classes', "Today's Classes", Icons.flash_on, Color(0xFFF59E0B), '/schedule'),
  QuickCard('trainer', 'My Trainer', Icons.person, Color(0xFF8B5CF6), '/training'),
  QuickCard('timetable', 'Timetable', Icons.calendar_month, Color(0xFF0EA5E9), '/schedule'),
  QuickCard('fees', 'Fees Due', Icons.account_balance_wallet, Color(0xFFEF4444), '/payments'),
  QuickCard('payments', 'Payment History', Icons.receipt_long, Color(0xFF14B8A6), '/payments'),
  QuickCard('progress', 'Progress', Icons.trending_up, Color(0xFF6366F1), '/progress'),
  QuickCard('belt', 'Belt / Rank', Icons.workspace_premium, Color(0xFFEAB308), '/progress'),
  QuickCard('events', 'Events', Icons.emoji_events, Color(0xFFF97316), '/events'),
  QuickCard('competition', 'Competition', Icons.military_tech, Color(0xFFDB2777), '/events'),
  QuickCard('chat', 'Chat Academy', Icons.chat_bubble, Color(0xFF22C55E), '/profile'),
  QuickCard('more', 'More', Icons.apps, Color(0xFF64748B), '/profile'),
];

const kPrograms = <Program>[
  Program(
    id: 'p1', sport: 'Karate', level: 'Blue Belt', trainer: 'Sensei Ryota',
    progress: 68, nextMilestone: 'Purple Belt',
    image: 'https://images.pexels.com/photos/6005457/pexels-photo-6005457.jpeg?auto=compress&cs=tinysrgb&w=800',
    color: Color(0xFFF97316),
  ),
  Program(
    id: 'p2', sport: 'Boxing', level: 'Intermediate', trainer: 'Coach Marcus',
    progress: 45, nextMilestone: 'Advanced',
    image: 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=800',
    color: Color(0xFFEA580C),
  ),
  Program(
    id: 'p3', sport: 'Taekwondo', level: 'Green Stripe', trainer: 'Master Jin Woo',
    progress: 55, nextMilestone: 'Blue Belt',
    image: 'https://images.pexels.com/photos/7045756/pexels-photo-7045756.jpeg?auto=compress&cs=tinysrgb&w=800',
    color: Color(0xFF10B981),
  ),
];

const kSchedule = <DaySchedule>[
  DaySchedule(day: 'Mon', date: '24', sessions: [
    Session(time: '06:00 AM', title: 'Karate Drills', trainer: 'Sensei Ryota', duration: '60 min', color: Color(0xFFF97316)),
    Session(time: '05:30 PM', title: 'Strength & Conditioning', trainer: 'Coach Lara', duration: '45 min', color: Color(0xFFF59E0B)),
  ]),
  DaySchedule(day: 'Tue', date: '25', sessions: [
    Session(time: '06:30 AM', title: 'Boxing Fundamentals', trainer: 'Coach Marcus', duration: '75 min', color: Color(0xFFEA580C)),
  ]),
  DaySchedule(day: 'Wed', date: '26', sessions: [
    Session(time: '06:00 AM', title: 'Taekwondo Forms', trainer: 'Master Jin Woo', duration: '60 min', color: Color(0xFF10B981)),
    Session(time: '07:00 PM', title: 'Sparring Practice', trainer: 'Sensei Ryota', duration: '60 min', color: Color(0xFFEF4444)),
  ]),
  DaySchedule(day: 'Thu', date: '27', sessions: [
    Session(time: '06:30 AM', title: 'Cardio & Agility', trainer: 'Coach Lara', duration: '45 min', color: Color(0xFF0EA5E9)),
  ]),
  DaySchedule(day: 'Fri', date: '28', sessions: [
    Session(time: '06:00 AM', title: 'Karate Kata', trainer: 'Sensei Ryota', duration: '60 min', color: Color(0xFFF97316)),
    Session(time: '06:00 PM', title: 'Friday Mix Class', trainer: 'Team', duration: '90 min', color: Color(0xFFDB2777)),
  ]),
  DaySchedule(day: 'Sat', date: '01', sessions: [
    Session(time: '08:00 AM', title: 'Open Mat', trainer: 'All Trainers', duration: '120 min', color: Color(0xFF8B5CF6)),
  ]),
  DaySchedule(day: 'Sun', date: '02', sessions: []),
];

const kPayments = <PaymentRow>[
  PaymentRow(id: 'pay1', label: 'Monthly Membership', amount: 480, date: '15 Jan 2026', method: 'Card'),
  PaymentRow(id: 'pay2', label: 'Tournament Registration', amount: 150, date: '08 Jan 2026', method: 'FPX'),
  PaymentRow(id: 'pay3', label: 'Uniform & Gear', amount: 220, date: '22 Dec 2025', method: 'Card'),
  PaymentRow(id: 'pay4', label: 'Monthly Membership', amount: 480, date: '15 Dec 2025', method: 'Bank'),
];

const kPayMethods = <PayMethod>[
  PayMethod(id: 'card', label: 'Credit / Debit Card', icon: Icons.credit_card),
  PayMethod(id: 'wallet', label: 'FPX / eWallet', icon: Icons.phone_iphone),
  PayMethod(id: 'bank', label: 'Bank Transfer', icon: Icons.account_balance),
];

const kEvents = <EventItem>[
  EventItem(
    id: 'e1', title: 'National Martial Arts Championship', date: '15 Mar 2026',
    countdown: 21, location: 'KL Grand Arena', category: 'Tournament',
    image: 'https://images.pexels.com/photos/7005050/pexels-photo-7005050.jpeg?auto=compress&cs=tinysrgb&w=800',
    registered: false,
  ),
  EventItem(
    id: 'e2', title: 'Boxing Masterclass w/ Pros', date: '05 Mar 2026',
    countdown: 11, location: 'Academy Main Hall', category: 'Workshop',
    image: 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=800',
    registered: true,
  ),
  EventItem(
    id: 'e3', title: 'Inter-Academy Taekwondo Meet', date: '28 Mar 2026',
    countdown: 34, location: 'Penang Sports Complex', category: 'Tournament',
    image: 'https://images.pexels.com/photos/7045756/pexels-photo-7045756.jpeg?auto=compress&cs=tinysrgb&w=800',
    registered: false,
  ),
];

const kCertificates = <Certificate>[
  Certificate(id: 'c1', title: 'Yellow Belt Karate', date: 'Jun 2024', issuer: 'Academy'),
  Certificate(id: 'c2', title: 'Boxing Level 1', date: 'Sep 2024', issuer: 'Coach Marcus'),
  Certificate(id: 'c3', title: 'Inter-School Silver Medal', date: 'Dec 2025', issuer: 'City Sports'),
];

const kSkills = <Skill>[
  Skill(name: 'Speed', value: 78, color: Color(0xFFF59E0B)),
  Skill(name: 'Power', value: 72, color: Color(0xFFEF4444)),
  Skill(name: 'Technique', value: 85, color: Color(0xFFF97316)),
  Skill(name: 'Agility', value: 80, color: Color(0xFF10B981)),
  Skill(name: 'Endurance', value: 75, color: Color(0xFF0EA5E9)),
];

const kAchievements = <Achievement>[
  Achievement(id: 'a1', title: '100 Classes', icon: Icons.local_fire_department, color: Color(0xFFF97316)),
  Achievement(id: 'a2', title: 'Belt Upgrade', icon: Icons.workspace_premium, color: Color(0xFF3B82F6)),
  Achievement(id: 'a3', title: 'Top Performer', icon: Icons.star, color: Color(0xFFEAB308)),
  Achievement(id: 'a4', title: 'Team Player', icon: Icons.groups, color: Color(0xFF8B5CF6)),
];

const kTrainerComments = <TrainerComment>[
  TrainerComment(trainer: 'Sensei Ryota', comment: 'Excellent progress on kata precision. Keep focusing on stance.', date: '22 Feb 2026'),
  TrainerComment(trainer: 'Coach Marcus', comment: 'Footwork improved significantly. Work more on jab-cross combos.', date: '18 Feb 2026'),
];

// Belt journey stages
const kBelts = <BeltStage>[
  BeltStage(name: 'White', color: Color(0xFFE5E7EB), done: true),
  BeltStage(name: 'Yellow', color: Color(0xFFFDE68A), done: true),
  BeltStage(name: 'Orange', color: Color(0xFFFED7AA), done: true),
  BeltStage(name: 'Green', color: Color(0xFF86EFAC), done: true),
  BeltStage(name: 'Blue', color: Color(0xFF93C5FD), done: true, current: true),
  BeltStage(name: 'Purple', color: Color(0xFFC4B5FD), done: false),
  BeltStage(name: 'Brown', color: Color(0xFFD6D3D1), done: false),
  BeltStage(name: 'Black', color: Color(0xFF1F2937), done: false),
];

class AttendanceStats {
  final int percentage, present, total;
  final List<AttendanceDay> thisMonth;
  final List<MissedClass> missed;
  const AttendanceStats({
    required this.percentage,
    required this.present,
    required this.total,
    required this.thisMonth,
    required this.missed,
  });
}

// Generated to match RN `attendanceData.thisMonth` logic.
final List<AttendanceDay> _kMonthDays = List<AttendanceDay>.generate(28, (i) {
  AttendanceStatus s;
  if (i % 7 == 6) {
    s = AttendanceStatus.off;
  } else if (i == 3 || i == 12) {
    s = AttendanceStatus.missed;
  } else if (i > 24) {
    s = AttendanceStatus.future;
  } else {
    s = AttendanceStatus.present;
  }
  return AttendanceDay(day: i + 1, status: s);
});

final AttendanceStats kAttendance = AttendanceStats(
  percentage: 87,
  present: 52,
  total: 60,
  thisMonth: _kMonthDays,
  missed: const [
    MissedClass(date: '13 Feb 2026', className: 'Boxing Fundamentals', reason: 'Reported sick'),
    MissedClass(date: '04 Feb 2026', className: 'Karate Drills', reason: 'No reason'),
  ],
);

const kHolidays = <Holiday>[
  Holiday(date: '08 Mar 2026', name: 'Chinese New Year Extended'),
  Holiday(date: '25 Mar 2026', name: 'Annual Day Off'),
];
