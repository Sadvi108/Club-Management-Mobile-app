export const student = {
  id: "SA-2026-0142",
  name: "Aarav Sharma",
  membership: "Gold Member",
  belt: "Blue Belt",
  beltColor: "#3B82F6",
  level: "Intermediate II",
  joinDate: "Jan 2024",
  photo: "https://i.pravatar.cc/200?img=15",
  phone: "+91 98765 43210",
  email: "aarav.sharma@email.com",
  parent: { name: "Rohan Sharma", phone: "+91 98111 22233", relation: "Father" },
  attendance: 87,
  fitness: 82,
  nextPayment: { amount: 4800, dueDate: "28 Feb 2026", label: "Monthly Membership" },
};

export const quickCards = [
  { id: "attendance", label: "Attendance", icon: "checkmark-circle", color: "#10B981", route: "/attendance" },
  { id: "classes", label: "Today's Classes", icon: "flash", color: "#F59E0B", route: "/(tabs)/schedule" },
  { id: "trainer", label: "My Trainer", icon: "person-circle", color: "#8B5CF6", route: "/(tabs)/training" },
  { id: "timetable", label: "Timetable", icon: "calendar", color: "#0EA5E9", route: "/(tabs)/schedule" },
  { id: "fees", label: "Fees Due", icon: "wallet", color: "#EF4444", route: "/(tabs)/payments" },
  { id: "payments", label: "Payment History", icon: "receipt", color: "#14B8A6", route: "/(tabs)/payments" },
  { id: "progress", label: "Progress Report", icon: "trending-up", color: "#6366F1", route: "/progress" },
  { id: "belt", label: "Belt / Rank", icon: "ribbon", color: "#EAB308", route: "/progress" },
  { id: "events", label: "Events", icon: "trophy", color: "#F97316", route: "/events" },
  { id: "competition", label: "Competition", icon: "medal", color: "#DB2777", route: "/events" },
  { id: "chat", label: "Chat Academy", icon: "chatbubbles", color: "#22C55E", route: "/(tabs)/profile" },
  { id: "more", label: "More", icon: "grid", color: "#64748B", route: "/(tabs)/profile" },
];

export const programs = [
  {
    id: "p1",
    sport: "Karate",
    level: "Blue Belt",
    trainer: "Sensei Ryota",
    progress: 68,
    nextMilestone: "Purple Belt",
    image: "https://images.pexels.com/photos/6005457/pexels-photo-6005457.jpeg?auto=compress&cs=tinysrgb&w=800",
    color: "#4F46E5",
  },
  {
    id: "p2",
    sport: "Boxing",
    level: "Intermediate",
    trainer: "Coach Marcus",
    progress: 45,
    nextMilestone: "Advanced",
    image: "https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=800",
    color: "#9333EA",
  },
  {
    id: "p3",
    sport: "Taekwondo",
    level: "Green Stripe",
    trainer: "Master Jin Woo",
    progress: 55,
    nextMilestone: "Blue Belt",
    image: "https://images.pexels.com/photos/7045756/pexels-photo-7045756.jpeg?auto=compress&cs=tinysrgb&w=800",
    color: "#10B981",
  },
];

export const schedule = [
  { day: "Mon", date: "24", sessions: [
    { time: "06:00 AM", title: "Karate Drills", trainer: "Sensei Ryota", duration: "60 min", color: "#4F46E5" },
    { time: "05:30 PM", title: "Strength & Conditioning", trainer: "Coach Lara", duration: "45 min", color: "#F59E0B" },
  ]},
  { day: "Tue", date: "25", sessions: [
    { time: "06:30 AM", title: "Boxing Fundamentals", trainer: "Coach Marcus", duration: "75 min", color: "#9333EA" },
  ]},
  { day: "Wed", date: "26", sessions: [
    { time: "06:00 AM", title: "Taekwondo Forms", trainer: "Master Jin Woo", duration: "60 min", color: "#10B981" },
    { time: "07:00 PM", title: "Sparring Practice", trainer: "Sensei Ryota", duration: "60 min", color: "#EF4444" },
  ]},
  { day: "Thu", date: "27", sessions: [
    { time: "06:30 AM", title: "Cardio & Agility", trainer: "Coach Lara", duration: "45 min", color: "#0EA5E9" },
  ]},
  { day: "Fri", date: "28", sessions: [
    { time: "06:00 AM", title: "Karate Kata", trainer: "Sensei Ryota", duration: "60 min", color: "#4F46E5" },
    { time: "06:00 PM", title: "Friday Mix Class", trainer: "Team", duration: "90 min", color: "#DB2777" },
  ]},
  { day: "Sat", date: "01", sessions: [
    { time: "08:00 AM", title: "Open Mat", trainer: "All Trainers", duration: "120 min", color: "#8B5CF6" },
  ]},
  { day: "Sun", date: "02", sessions: [] },
];

export const payments = [
  { id: "pay1", label: "Monthly Membership", amount: 4800, date: "15 Jan 2026", status: "paid", method: "Card" },
  { id: "pay2", label: "Tournament Registration", amount: 1500, date: "08 Jan 2026", status: "paid", method: "Wallet" },
  { id: "pay3", label: "Uniform & Gear", amount: 2200, date: "22 Dec 2025", status: "paid", method: "Card" },
  { id: "pay4", label: "Monthly Membership", amount: 4800, date: "15 Dec 2025", status: "paid", method: "Bank" },
];

export const events = [
  {
    id: "e1",
    title: "National Martial Arts Championship",
    date: "15 Mar 2026",
    countdown: 21,
    location: "Mumbai Grand Arena",
    category: "Tournament",
    image: "https://images.pexels.com/photos/7005050/pexels-photo-7005050.jpeg?auto=compress&cs=tinysrgb&w=800",
    registered: false,
  },
  {
    id: "e2",
    title: "Boxing Masterclass w/ Pros",
    date: "05 Mar 2026",
    countdown: 11,
    location: "Academy Main Hall",
    category: "Workshop",
    image: "https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=800",
    registered: true,
  },
  {
    id: "e3",
    title: "Inter-Academy Taekwondo Meet",
    date: "28 Mar 2026",
    countdown: 34,
    location: "Pune Sports Complex",
    category: "Tournament",
    image: "https://images.pexels.com/photos/7045756/pexels-photo-7045756.jpeg?auto=compress&cs=tinysrgb&w=800",
    registered: false,
  },
];

export const certificates = [
  { id: "c1", title: "Yellow Belt Karate", date: "Jun 2024", issuer: "Academy" },
  { id: "c2", title: "Boxing Level 1", date: "Sep 2024", issuer: "Coach Marcus" },
  { id: "c3", title: "Inter-School Silver Medal", date: "Dec 2025", issuer: "City Sports" },
];

export const trainerComments = [
  { trainer: "Sensei Ryota", comment: "Excellent progress on kata precision. Keep focusing on stance.", date: "22 Feb 2026" },
  { trainer: "Coach Marcus", comment: "Footwork improved significantly. Work more on jab-cross combos.", date: "18 Feb 2026" },
];

export const skills = [
  { name: "Speed", value: 78, color: "#F59E0B" },
  { name: "Power", value: 72, color: "#EF4444" },
  { name: "Technique", value: 85, color: "#4F46E5" },
  { name: "Agility", value: 80, color: "#10B981" },
  { name: "Endurance", value: 75, color: "#0EA5E9" },
];

export const achievements = [
  { id: "a1", title: "100 Classes", icon: "flame", color: "#F97316" },
  { id: "a2", title: "Belt Upgrade", icon: "ribbon", color: "#3B82F6" },
  { id: "a3", title: "Top Performer", icon: "star", color: "#EAB308" },
  { id: "a4", title: "Team Player", icon: "people", color: "#8B5CF6" },
];

export const attendanceData = {
  percentage: 87,
  present: 52,
  total: 60,
  thisMonth: Array.from({ length: 28 }, (_, i) => ({
    day: i + 1,
    status: i % 7 === 6 ? "off" : i === 3 || i === 12 ? "missed" : i > 24 ? "future" : "present",
  })),
  missed: [
    { date: "13 Feb 2026", class: "Boxing Fundamentals", reason: "Reported sick" },
    { date: "04 Feb 2026", class: "Karate Drills", reason: "No reason" },
  ],
};

export const holidays = [
  { date: "08 Mar 2026", name: "Holi Festival" },
  { date: "25 Mar 2026", name: "Annual Day Off" },
];
