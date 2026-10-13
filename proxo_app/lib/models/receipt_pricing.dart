/// Receipt-only projection of immutable purchase-time data.
/// Never consults current prices, rates, promo configuration or wallet totals.
class ReceiptPricing {
  final int? originalIqd;
  final int? discountIqd;
  final int? totalIqd;
  const ReceiptPricing({this.originalIqd, this.discountIqd, this.totalIqd});
  bool get noPaymentRequired => totalIqd == 0;

  factory ReceiptPricing.from(Map<String, dynamic> ad) {
    final total = storedMoney(ad['pricing_total_iqd_snapshot']) ??
        storedMoney(ad['charged_price_iqd']);
    final budget = storedMoney(ad['pricing_ad_budget_iqd_snapshot']);
    final fee = storedMoney(ad['pricing_service_fee_iqd_snapshot']);
    final components = [
      'global_discount_iqd',
      'direct_discount_iqd',
      'level_discount_iqd',
    ].map((key) => storedMoney(ad[key])).whereType<int>().toList();
    final discount = storedMoney(ad['pricing_discount_iqd_snapshot']) ??
        (components.isEmpty ? null : components.fold<int>(0, (a, b) => a + b));
    final original = budget != null && fee != null
        ? budget + fee
        : total != null && discount != null
            ? total + discount
            : null;
    return ReceiptPricing(
      originalIqd: original,
      discountIqd: discount,
      totalIqd: total,
    );
  }
}

num? storedNumber(dynamic value) {
  final parsed = value is num
      ? value
      : value is String
          ? num.tryParse(value.trim())
          : null;
  return parsed != null && parsed.isFinite ? parsed : null;
}

int? storedMoney(dynamic value) {
  final number = storedNumber(value);
  return number != null && number >= 0 ? number.round() : null;
}

String receiptText(dynamic value) {
  if (value is! String && value is! num) return '';
  if (value is num && !value.isFinite) return '';
  final text = value.toString().trim();
  if ([
        'null',
        'undefined',
        'nan',
        'infinity',
        '-infinity',
      ].contains(text.toLowerCase()) ||
      text.startsWith('Instance of')) {
    return '';
  }
  return text;
}

/// Convert only with the currency and exchange rate stored on this transaction.
int? storedTransactionIqd(Map<String, dynamic> transaction) {
  final amount = storedNumber(transaction['amount']);
  if (amount == null) return null;
  final currency = receiptText(transaction['currency']).toUpperCase();
  if (currency == 'IQD') return amount.abs().round();
  final rate = storedNumber(transaction['fx_rate']);
  if (currency == 'USD' && rate != null && rate > 0) {
    return (amount.abs() * rate).round();
  }
  return null;
}
