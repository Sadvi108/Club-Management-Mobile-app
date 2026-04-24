# Apex Academy — Sports Academy Student App (PRD)

## Overview
Premium sports academy student mobile app (React Native Expo, light mode) for martial-arts + multi-sport learners. Frontend-only prototype with mock data.

## Tech
- Expo SDK 54, Expo Router, React Native 0.81, TypeScript
- @expo/vector-icons (Ionicons), expo-linear-gradient
- No backend — all data is seeded in `/src/mockData.ts`

## Theme
- Light mode, blue→purple gradient accents (`#4F46E5` → `#9333EA`)
- Poppins/Inter scale defined in `/src/theme.ts`
- Cards with 16–24px radius, elegant shadows, 8pt grid spacing

## Screens (10)
1. **Splash** (`/`) — animated logo ring, auto-advances to login in ~2s
2. **Login** (`/login`) — Student/Parent tabs, ID/password, forgot pwd, QR scan login CTA
3. **Home Dashboard** (`/(tabs)/home`) — gradient header w/ profile+bell+stats, quick-access bar (Attendance/Timetable/Virtual ID/Profile), Fees-Due card, Today's Class, 12-icon Quick Access grid, Featured Event banner
4. **My Training** (`/(tabs)/training`) — Weekly streak hero, enrolled programs (Karate/Boxing/Taekwondo) with progress + upgrade level
5. **Schedule** (`/(tabs)/schedule`) — 7-day chip strip, session timeline w/ trainer & duration, holiday card
6. **Attendance** (`/attendance`) — Radial % ring, monthly calendar with present/missed, QR check-in CTA, missed history
7. **Fees & Payments** (`/(tabs)/payments`) — Due card w/ Pay Now, quick packages, history list, payment method modal (Card/Wallet/Bank)
8. **Progress** (`/progress`) — Fitness score card, Belt journey timeline (White→Black), skill bars, achievement badges, trainer feedback quotes
9. **Events & Competition** (`/events`) — Upcoming/Registered/Certificates tabs, countdown cards, register CTA, downloadable certificates
10. **Profile** (`/(tabs)/profile`) — Gradient header w/ avatar & membership, Virtual ID card w/ barcode+QR, contact info, certificates, settings list, Renew CTA, logout

## Navigation
- Bottom tabs: Home · Training · **QR (FAB)** · Schedule · Payments · Profile
- Floating center QR button pushes `/qr-scan` modal (animated scan laser, success state)

## Key UX
- SafeAreaView everywhere, KeyboardAvoidingView on login
- testID on every interactive element
- All mock data covers martial arts + multi-sport; ₹INR currency

## Business Enhancement
- "Refer a Friend — Earn ₹500" in Profile settings
- "Renew Membership — 20% OFF" gradient CTA in profile for retention + upsell
