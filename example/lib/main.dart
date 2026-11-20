import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'transactions/transactions.dart';

void main() {
  runApp(buildApp(GetIt.instance));
}

/// The app starts on the state-management choice, which registers the chosen
/// adapter in [services] before any screen reads state.
Widget buildApp(
  GetIt services, {
  LoadTransactions load = loadDemoTransactions,
}) {
  return TransactionsApp(services: services, load: load);
}

Future<List<TransactionEntry>> loadDemoTransactions() async {
  await Future<void>.delayed(const Duration(milliseconds: 750));
  return const [
    TransactionEntry('Café Central', pending: true),
    TransactionEntry('Salary deposit', pending: false),
    TransactionEntry('Bookstore', pending: true),
  ];
}
