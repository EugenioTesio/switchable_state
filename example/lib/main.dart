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

var _demoRequests = 0;

/// A pretend backend that fails every other request, so the app can show how
/// the transactions page reacts: the first load works, the next Refresh
/// fails and shows a snack bar, and its Retry works again.
Future<List<TransactionEntry>> loadDemoTransactions() async {
  final request = ++_demoRequests;
  await Future<void>.delayed(const Duration(milliseconds: 750));
  if (request.isEven) {
    throw StateError('The demo backend fails every other request.');
  }
  return const [
    TransactionEntry('Café Central', pending: true),
    TransactionEntry('Salary deposit', pending: false),
    TransactionEntry('Bookstore', pending: true),
  ];
}
