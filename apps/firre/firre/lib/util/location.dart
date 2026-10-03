import 'package:geolocator/geolocator.dart';

/// A location lookup that failed, with a message to show the user.
class LocationException implements Exception {
  LocationException(this.message);

  final String message;

  @override
  String toString() => 'LocationException: $message';
}

bool isLocationGranted(LocationPermission permission) =>
    permission == LocationPermission.always ||
    permission == LocationPermission.whileInUse;

/// The phone's current position, asking for permission first if needed.
/// Throws [LocationException] when it can't be had.
Future<Position> currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Platstjänster är avstängda på telefonen.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!isLocationGranted(permission)) {
      throw LocationException('Appen har inte tillgång till din plats.');
    }
    return await Geolocator.getCurrentPosition();
  } on LocationException {
    rethrow;
  } catch (_) {
    throw LocationException('Kunde inte hitta din plats.');
  }
}
