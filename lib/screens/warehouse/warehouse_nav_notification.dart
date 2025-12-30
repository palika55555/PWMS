import 'package:flutter/widgets.dart';

/// Bubble-up navigation requests inside the Warehouse module.
/// Used for actions like "after saving issue -> jump to approvals/issues".
class WarehouseNavigateNotification extends Notification {
  final int tabIndex; // WarehouseScreen bottom-nav index
  final String? approvalsMode; // 'receipt' | 'issue' (ReceiptsPendingScreen segmented mode)

  const WarehouseNavigateNotification({
    required this.tabIndex,
    this.approvalsMode,
  });
}







