import 'package:equatable/equatable.dart';

import 'printer_interface_type.dart';

class PrinterDevice extends Equatable {
  final String id;
  final PrinterInterfaceType interfaceType;

  const PrinterDevice({required this.id, required this.interfaceType});

  bool get isValid => id.trim().isNotEmpty;

  @override
  List<Object?> get props => [id, interfaceType];
}
