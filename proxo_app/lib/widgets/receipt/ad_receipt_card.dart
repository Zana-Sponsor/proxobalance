import 'package:flutter/material.dart';

import '../../l10n/ad_detail_strings.dart';
import '../../models/ad_receipt_data.dart';
import 'receipt_kit.dart';

class AdReceiptCard extends StatelessWidget {
  final AdReceiptData r;
  final AdDetailStrings l;
  final void Function(String value) onCopy;

  const AdReceiptCard({
    super.key,
    required this.r,
    required this.l,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    const TextDirection ltr = TextDirection.ltr;

    return ReceiptCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── ٣) سەرووی پسوولە ─────────────────────────────────────────────
          ReceiptHeader(title: l.receiptTitle),
          const ReceiptDivider(),

          // ── ١٠) زانیاری سەرەوە ──────────────────────────────────────────
          ReceiptRows(<Widget?>[
            ReceiptIdRow(
              label: l.adId,
              value: r.adId,
              onLongPress: () => onCopy(r.adId),
            ),
            ReceiptRow(label: l.date, value: r.date, valueDirection: ltr),
          ]),
          const ReceiptDivider(),

          // ── ١١) ئامانجی ڕیکلام ──────────────────────────────────────────
          ReceiptSectionHeading(l.sectionTarget),
          ReceiptRows(<Widget?>[
            ReceiptRow(label: l.age, value: r.age, valueDirection: r.ageDir),
            ReceiptRow(
              label: l.gender,
              value: r.gender,
              valueDirection: receiptDirOf(r.gender),
            ),
            ReceiptRow(
              label: l.location,
              value: r.location,
              valueDirection: receiptDirOf(r.location),
            ),
            ReceiptRow(
              label: l.device,
              value: r.device,
              valueDirection: r.deviceDir,
            ),
            ReceiptRow(
              label: l.category,
              value: r.category,
              valueDirection: receiptDirOf(r.category),
            ),
          ]),
          const ReceiptDivider(),

          // ── ١٢) پوختە ───────────────────────────────────────────────────
          ReceiptSectionHeading(l.sectionSummary),
          ReceiptRows(<Widget?>[
            ReceiptMoneyRow(
              label: l.originalAmount,
              value: r.originalIqd ?? '—',
            ),
            if (r.discountIqd != null)
              ReceiptMoneyRow(label: l.discount, value: r.discountIqd!),
            ReceiptMoneyRow(
              label: l.totalIqd,
              value: r.totalIqd ?? '—',
              important: true,
            ),
          ]),
          const ReceiptDivider(),

          // ── ١٤) زانیاری پارەدان ─────────────────────────────────────────
          ReceiptSectionHeading(l.sectionPayment),
          ReceiptRows(<Widget?>[
            ReceiptRow(
              label: l.paymentMethod,
              value: r.payment,
              valueDirection: r.paymentDir,
            ),
            if (r.transactionId != null)
              ReceiptIdRow(
                label: l.transactionId,
                value: r.transactionId!,
                onLongPress: () => onCopy(r.transactionId!),
              ),
          ]),
          const ReceiptDivider(),

          // ── ١٥) ناوی ڕیکلام + ژ.م پسوولە ────────────────────────────────
          ReceiptRows(<Widget?>[
            ReceiptRow(
              label: l.adName,
              value: r.adName,
              valueDirection: r.adNameDir,
            ),
            ReceiptIdRow(
              label: l.receiptNo,
              value: r.uid,
              onLongPress: () => onCopy(r.uid),
            ),
          ]),
        ],
      ),
    );
  }
}
