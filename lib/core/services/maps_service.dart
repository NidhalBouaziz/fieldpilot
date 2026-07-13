import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

import '../models/customer.dart';

class MapPoint {
  const MapPoint(this.latitude, this.longitude, {this.approximate = false});

  final double latitude;
  final double longitude;
  final bool approximate;
}

const Map<String, MapPoint> tunisiaGovernoratePoints = {
  'ARIANA': MapPoint(36.8625, 10.1956, approximate: true),
  'BEJA': MapPoint(36.7333, 9.1833, approximate: true),
  'BEN AROUS': MapPoint(36.7531, 10.2189, approximate: true),
  'BIZERTE': MapPoint(37.2744, 9.8739, approximate: true),
  'GABES': MapPoint(33.8815, 10.0982, approximate: true),
  'GAFSA': MapPoint(34.4250, 8.7842, approximate: true),
  'JENDOUBA': MapPoint(36.5011, 8.7802, approximate: true),
  'KAIROUAN': MapPoint(35.6781, 10.0963, approximate: true),
  'KASSERINE': MapPoint(35.1676, 8.8365, approximate: true),
  'KEBELI': MapPoint(33.7044, 8.9690, approximate: true),
  'KEF': MapPoint(36.1822, 8.7147, approximate: true),
  'MAHDIA': MapPoint(35.5047, 11.0622, approximate: true),
  'MANOUBA': MapPoint(36.8101, 10.0956, approximate: true),
  'MEDENINE': MapPoint(33.3549, 10.5055, approximate: true),
  'MONASTIR': MapPoint(35.7770, 10.8262, approximate: true),
  'NABEUL': MapPoint(36.4513, 10.7350, approximate: true),
  'SFAX': MapPoint(34.7406, 10.7603, approximate: true),
  'SIDI BOUZID': MapPoint(35.0382, 9.4849, approximate: true),
  'SILIANA': MapPoint(36.0840, 9.3708, approximate: true),
  'SOUSSE': MapPoint(35.8256, 10.6360, approximate: true),
  'TATAOUINE': MapPoint(32.9297, 10.4518, approximate: true),
  'TOZEUR': MapPoint(33.9197, 8.1335, approximate: true),
  'TUNIS': MapPoint(36.8065, 10.1815, approximate: true),
  'ZAGHOUAN': MapPoint(36.4029, 10.1429, approximate: true),
};

final Map<String, MapPoint?> _geocodeCache = {};

MapPoint? mapPointForCustomer(Customer customer) {
  if (customer.latitude != null && customer.longitude != null) {
    return MapPoint(customer.latitude!, customer.longitude!);
  }

  final governorate = customer.governorate.trim().toUpperCase();
  final city = customer.city.trim().toUpperCase();
  return tunisiaGovernoratePoints[governorate] ??
      tunisiaGovernoratePoints[city];
}

Future<MapPoint?> resolveMapPointForCustomer(Customer customer) async {
  if (customer.latitude != null && customer.longitude != null) {
    return MapPoint(customer.latitude!, customer.longitude!);
  }

  final query = mapsAddressQueryForCustomer(customer);
  if (query.isNotEmpty) {
    if (_geocodeCache.containsKey(query)) return _geocodeCache[query];
    try {
      final locations = await locationFromAddress(query);
      final first = locations.isEmpty ? null : locations.first;
      final point =
          first == null ? null : MapPoint(first.latitude, first.longitude);
      _geocodeCache[query] = point;
      if (point != null) return point;
    } catch (_) {
      _geocodeCache[query] = null;
    }
  }

  return mapPointForCustomer(customer);
}

String mapsAddressQueryForCustomer(Customer customer) {
  final parts = [
    customer.address,
    customer.city,
    customer.governorate,
    'Tunisia',
  ].whereType<String>().map((part) => part.trim()).where((part) {
    return part.isNotEmpty;
  }).toList();

  return parts.join(', ');
}

String mapsQueryForCustomer(Customer customer) {
  final addressQuery = mapsAddressQueryForCustomer(customer);
  if (addressQuery.isNotEmpty) return addressQuery;
  final point = mapPointForCustomer(customer);
  if (point != null) return '${point.latitude},${point.longitude}';
  return customer.displayName;
}

Uri mapsSearchUriForCustomer(Customer customer) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': mapsQueryForCustomer(customer),
  });
}

Future<bool> openCustomerInMaps(Customer customer) {
  return launchUrl(
    mapsSearchUriForCustomer(customer),
    mode: LaunchMode.externalApplication,
  );
}
