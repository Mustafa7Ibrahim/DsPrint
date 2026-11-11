import 'package:equatable/equatable.dart';

import '../../domain/entities/printer_device.dart';

enum PrinterConnectionStatus { checking, connected, disconnected }

class PrinterConnectionState extends Equatable {
  final Map<PrinterDevice, PrinterConnectionStatus> statuses;

  const PrinterConnectionState([this.statuses = const {}]);

  @override
  List<Object?> get props => [statuses];
}
