# Deep Payments + Profile Pass — Implementation Plan

> Execute phases consecutively. Each phase: implement → `flutter analyze --no-pub` (0 errors in lib/) → commit. Final phase builds APK + previews.

## Phase 0 — Discovery (DONE, facts below)

Probed the live API (`apimac.zyncbook.com`) with working accounts. The
ID the user gave (`190618101314` / `Fl33tsquash`) returns **404 Account
not found** on this server under every userType — it belongs to a
different deployment. Used `Aunty1`/`1234` (student) + `GMHaffiz`/`12345`
(instructor) for shapes.

**Sources:** `swag.json` (OpenAPI), live curl probes, current
`lib/services/api.dart`, `api_service.dart`, `payments_screen.dart`,
`outstanding_invoices_screen.dart`, `profile_screen.dart`.

### Confirmed API facts (use these, do not invent)

1. **Outstanding/Fetch row** already carries everything for owner-labeled
   invoices — no new call needed:
   ```
   {invoiceId:715993, studentId:19559, studentName:"AZMAN BIN AZAM",
    icNo:"azman123", invoiceAmount:250.0, dueAmount:250.0,
    invoiceDescription:"KYORUGI fee for OPEN CHAMPIONSHIP 2024",
    period:"December-2024", transactionType:"KYORUGI",
    paymentStatus:"Approval Pending", centerName:"...", invoiceDate:"..."}
   ```

2. **Receipt row** (`/Reports/Receipts`):
   ```
   {id:919368, receiptNo:10000336, receiptDate:"...", receiptAmount:50.0,
    paymentMethod:"...", icNo:"azman123", name:"AZMAN BIN AZAM"}
   ```
   `id` == paymentId. No invoiceId in the row → use `0`.

3. **ReceiptAsPDF** `GET /Utilities/ReceiptAsPDF/{clubId}/{paymentId}/{invoiceId}`
   returns **raw PDF bytes** (`%PDF-1.3...`), NOT JSON, NOT a URL.
   Verified: `/Utilities/ReceiptAsPDF/49/919368/0` → 200, body is a PDF.
   `clubId` = `49` for Aunty1 (from `clubPic` URL `.../Logo//49.png`;
   authData carries `clubId`).
   **Current bug:** `Api.utilitiesReceiptAsPDF` → `ApiService.get` →
   `jsonDecode(body)` throws on binary; `_viewReceiptPDF` then
   `launchUrl`s a non-URL. That is why "receipts cannot be downloaded."

4. **UpdateProfile** `POST /Profile/UpdateProfile` is **multipart/form-data**
   (NOT JSON). Fields:
   `Id, Name, IcNo, Gender, Address1, Address2, Address3, Address4,
   PostalCode, EmailAddress, HandPhone, CurrentGrade, ProfilePic,
   NewPassword, Height, Weight, TshirtSize, ClassName, StandardId,
   Schoolname, Dob, Bloodtype, Bmi, Healthstatus, Foodtype`.
   `ProfilePic` is typed `string` in the multipart form (base64 image
   string, not a binary file part).
   **Current bug:** `Api.profileUpdateProfile(Map)` → `ApiService.post`
   sends JSON; the server wants multipart → only some fields stick.

5. **No read-back of a student photo anywhere.** `MyInfo`,
   `StudentAddtnlInfo`, and authData contain NO student photo field —
   only `clubPic` (club logo). `StudentAddtnlInfo` returns health:
   `{height, dob, bloodtype, healthstatus, schoolname, classname,
   tshirtSize, foodtype, standardid}`.

### Allowed APIs / packages
- `Api.outstandingFetch`, `Api.reportsReceipts` — already wrapped.
- New: `ApiService.getBytes(endpoint)` → `Uint8List` (raw, no jsonDecode).
- New: `ApiService.postMultipart(endpoint, fields)` → multipart POST.
- New deps: `image_picker` (pick avatar) and `printing` (open/share PDF
  bytes cross-platform). Both are mainstream, null-safe, web-capable.

### Anti-patterns to avoid
- Do NOT `jsonDecode` the ReceiptAsPDF response — it is binary.
- Do NOT send UpdateProfile as JSON — it is multipart/form-data.
- Do NOT invent a "get student photo" endpoint — none exists.
- Do NOT block on the user-supplied ID — it 404s here; use the data shapes.

---

## Phase 1 — Owner-labeled invoices (#1)

**What:** Replace "Invoice #N" with the real `invoiceDescription` +
`studentName` everywhere an outstanding invoice renders.

**Files:**
- `lib/screens/outstanding_invoices_screen.dart` — the `_invoiceCard`
  title currently falls back to `Invoice #${index+1}`. Change title to
  `invoiceDescription` (keys: `invoiceDescription`, `description`,
  `particulars`), subtitle line to `studentName` + `period`. Keep amount +
  status pill + tap→detail.
- `lib/screens/payments_screen.dart` — the outstanding list rows
  (`_invoiceLabel`) already probe `invoiceName/description/...`; add
  `invoiceDescription` first and append `studentName` as a second line.

**Verify:** Login Aunty1 → Payments / Outstanding Invoices → rows show
"KYORUGI fee for OPEN CHAMPIONSHIP 2024 · AZMAN BIN AZAM · December-2024",
not "Invoice #1". `grep -n "Invoice #" lib/screens/*.dart` → only the
last-resort fallback remains.

**Anti-pattern guard:** keep `Invoice #${i+1}` only as the final fallback
when `invoiceDescription` is genuinely empty.

---

## Phase 2 — Receipt download wired (#2 part a)

**What:** Fetch the PDF bytes and open/share them.

**Files:**
- `pubspec.yaml` — add `printing: ^5.13.4`.
- `lib/services/api_service.dart` — add:
  ```dart
  static Future<Uint8List> getBytes(String endpoint) async {
    final res = await http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    throw Exception('Error ${res.statusCode}');
  }
  ```
  (import `dart:typed_data`).
- `lib/services/api.dart` — add `utilitiesReceiptAsPdfBytes({clubId, paymentId, invoiceId})`
  → `ApiService.getBytes('/Utilities/ReceiptAsPDF/...')`.
- `lib/screens/payments_screen.dart` — rewrite `_viewReceiptPDF`: read
  `clubId` from `session.authData['clubId']`, `paymentId` from
  `m['id'] ?? m['paymentId']`, `invoiceId` from `m['invoiceId'] ?? 0`;
  call the bytes method; `await Printing.sharePdf(bytes: pdf, filename: 'receipt_$receiptNo.pdf')`.
  Snackbar on empty/throw.

**Verify:** Payments → receipt row → PDF button → native share/open sheet
with the receipt PDF. No "FormatException ... not valid JSON".

**Anti-pattern guard:** do not route the bytes through `findRecordList`
or `jsonDecode`; do not `launchUrl`.

---

## Phase 3 — Pay-now shows student + invoice details (#2 part b)

**What:** The pay flow (modal + gateway dialog + "Pay Selected") must name
the student(s) and invoice description(s) being paid, not just a total.

**Files:**
- `lib/screens/payments_screen.dart` — in `_openPayModal` / the selected-
  invoice pay path, build a "Paying for" summary from the selected rows:
  each line = `studentName · invoiceDescription · RM amount`. Show it in
  the pay sheet above the method selector and in the gateway confirm
  dialog. Reuse `_invoiceLabel` + a new `_invoiceOwner(row)` reading
  `studentName/name`.

**Verify:** select 1–2 invoices → Pay → sheet lists each as
"AZMAN BIN AZAM · KYORUGI fee … · RM 250.00" with the running total.

---

## Phase 4 — Full edit profile + photo (#3)

**What:** Edit sheet covers all UpdateProfile fields; multipart POST;
pick + show an avatar.

**Files:**
- `pubspec.yaml` — add `image_picker: ^1.1.2`.
- `lib/services/api_service.dart` — add:
  ```dart
  static Future<dynamic> postMultipart(String endpoint, Map<String,String> fields) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
    req.headers.addAll(_headers..remove('Content-Type'));
    fields.forEach((k,v){ if (v.isNotEmpty) req.fields[k]=v; });
    final res = await http.Response.fromStream(await req.send());
    return _handle(res);
  }
  ```
  (Confirm `_headers` exposes the bearer token; multipart sets its own
  Content-Type boundary — must NOT force application/json.)
- `lib/services/api.dart` — change `profileUpdateProfile` to call
  `ApiService.postMultipart('/Profile/UpdateProfile', stringFields)`.
- `lib/screens/profile_screen.dart` — expand `_openEditSheet`: text fields
  for Name, IcNo, Gender, Address1–4, PostalCode, Email, HandPhone,
  Height, Weight, plus an avatar picker (image_picker →
  `base64Encode(bytes)` → `ProfilePic` field). Prefill from `myInfo` +
  `studentAddtnlInfo`. On save → `profileUpdateProfile(fields)` →
  refresh. Show the picked image immediately; persist its base64 in
  `shared_preferences` keyed by student id so it shows on return (server
  has no photo read-back — see Phase 0 fact 5).

**Verify:** Profile → Edit → all fields editable + save persists (re-open
shows new values via MyInfo). Pick a photo → avatar updates + survives
app restart (local cache). `flutter analyze` clean.

**Anti-pattern guard:** multipart, never JSON; do not expect a photo URL
back from the server.

---

## Phase 5 — 2-minute payment lock (#4)

**What:** When the pay screen/sheet opens, start a 120s countdown; while
it runs no second payment can be initiated.

**Files:**
- `lib/services/user_session.dart` — add `DateTime? paymentLockUntil;`
  + `bool get paymentLocked => paymentLockUntil != null &&
  DateTime.now().isBefore(paymentLockUntil!);` + `void startPaymentLock()
  { paymentLockUntil = DateTime.now().add(const Duration(minutes: 2));
  notifyListeners(); }` + `void clearPaymentLock()`.
- `lib/screens/payments_screen.dart` — on opening the pay sheet call
  `startPaymentLock()`; render a `Countdown` (mm:ss) in the sheet header;
  disable "Pay" / "Pay Selected" on other invoices while
  `session.paymentLocked`; auto-clear + re-enable at 0. Clear the lock on
  successful confirm/cancel.

**Verify:** open Pay → 02:00 ticks down; other pay buttons disabled;
reaches 00:00 → unlock. Cancel before 0 → unlock immediately.

**Anti-pattern guard:** timer is client-only (no API); use a single
`Timer.periodic`, dispose it in `dispose()`.

---

## Phase 6 — Verification + ship

1. `flutter analyze --no-pub` → 0 errors in lib/.
2. `flutter build web --release --no-pub` → `√ Built build\web`; preview
   (Aunty1) → invoices labeled, receipt opens, edit-all + photo, pay timer.
3. Commit per phase; push; CI APK; GitHub release.

## Known gaps (flag to user, not bugs)
- Student photo has no server read-back endpoint; uploaded `ProfilePic`
  may store server-side but nothing exposes it — app shows the locally
  cached pick. If the server later returns a photo URL in MyInfo, wire it
  then (~3 lines).
- `ProfilePic` multipart encoding assumed base64 string (swagger types it
  `string`). If the server rejects, fallback: send as a file part
  (`http.MultipartFile.fromBytes('ProfilePic', ...)`).
