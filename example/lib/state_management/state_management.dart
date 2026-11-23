import 'package:get_it/get_it.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';
import 'package:switchable_state_getx/switchable_state_getx.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';
import 'package:switchable_state/switchable_state.dart';

/// One library the user can pick on the start screen.
final class StateManagementOption {
  const StateManagementOption({
    required this.name,
    required this.summary,
    required this.adapter,
  });

  final String name;
  final String summary;
  final StateAdapter adapter;
}

const stateManagementOptions = [
  StateManagementOption(
    name: 'Cubit',
    summary: 'flutter_bloc: Cubit, BlocBuilder and BlocSelector',
    adapter: CubitStateAdapter(),
  ),
  StateManagementOption(
    name: 'GetX',
    summary: 'get: Rx values read inside Obx',
    adapter: GetXStateAdapter(),
  ),
  StateManagementOption(
    name: 'MobX',
    summary: 'mobx: Observable and Computed read inside Observer',
    adapter: MobXStateAdapter(),
  ),
  StateManagementOption(
    name: 'Provider',
    summary: 'provider: ChangeNotifier with Consumer and Selector',
    adapter: ProviderStateAdapter(),
  ),
  StateManagementOption(
    name: 'Riverpod',
    summary: 'flutter_riverpod: Notifier watched by a Consumer',
    adapter: RiverpodStateAdapter(),
  ),
];

/// Injects the chosen library: registers its adapter in [services],
/// replacing any earlier choice.
void selectStateManagement(GetIt services, StateManagementOption option) {
  if (services.isRegistered<StateAdapter>()) {
    services.unregister<StateAdapter>();
  }
  services.registerSingleton<StateAdapter>(option.adapter);
}

/// The option whose adapter is registered, or null before a choice.
StateManagementOption? selectedStateManagement(GetIt services) {
  if (!services.isRegistered<StateAdapter>()) return null;
  final adapter = services<StateAdapter>();
  return stateManagementOptions.firstWhere(
    (option) =>
        identical(option.adapter, adapter) ||
        option.adapter.runtimeType == adapter.runtimeType,
  );
}
