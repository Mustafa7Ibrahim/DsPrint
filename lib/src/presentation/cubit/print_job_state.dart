import 'package:equatable/equatable.dart';

import '../../core/error/ds_print_failure.dart';

sealed class PrintJobState extends Equatable {
  const PrintJobState();

  @override
  List<Object?> get props => [];
}

final class PrintJobIdle extends PrintJobState {
  const PrintJobIdle();
}

final class PrintJobInProgress extends PrintJobState {
  const PrintJobInProgress();
}

final class PrintJobCompleted extends PrintJobState {
  const PrintJobCompleted();
}

final class PrintJobFailure extends PrintJobState {
  final DsPrintFailure failure;

  const PrintJobFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
