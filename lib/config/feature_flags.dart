/// Prepay (advance term payment) execution. Pricing/preview is always on;
/// the actual /Outstanding/PayInvoices term charge stays disabled until the
/// pay contract is verified on a plan-enabled account (see the prepay plan's
/// live-verification task).
const bool kPrepayPayEnabled = false;
