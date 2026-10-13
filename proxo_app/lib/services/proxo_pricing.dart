/// Shared pricing constants used by ad creation and ad details.
///
/// The authoritative checkout amount is still recomputed on Supabase. This
/// value only keeps the client-side 80/20 price breakdown consistent with the
/// database snapshots while the form is being edited.
abstract final class ProxoPricing {
  static const double serviceFeePercent = 0.20;
}
