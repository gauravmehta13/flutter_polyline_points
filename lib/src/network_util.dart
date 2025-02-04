import 'dart:convert';

import 'package:http/http.dart' as http;

import '../src/PointLatLng.dart';
import '../src/utils/polyline_waypoint.dart';
import '../src/utils/request_enums.dart';
import 'utils/polyline_result.dart';

class NetworkUtil {
  static const String statusOk = "ok";

  ///Get the encoded string from google directions api
  ///
  Future<PolylineResult> getRouteBetweenCoordinates(
      String googleApiKey,
      PointLatLng origin,
      PointLatLng destination,
      TravelMode travelMode,
      List<PolylineWayPoint> wayPoints,
      bool avoidHighways,
      bool avoidTolls,
      bool avoidFerries,
      bool optimizeWaypoints) async {
    String mode = travelMode.toString().replaceAll('TravelMode.', '');
    PolylineResult result = PolylineResult();
    var params = {
      "origin": "${origin.latitude},${origin.longitude}",
      "destination": "${destination.latitude},${destination.longitude}",
      "mode": mode,
      "avoidHighways": "$avoidHighways",
      "avoidFerries": "$avoidFerries",
      "avoidTolls": "$avoidTolls",
      "key": googleApiKey
    };
    if (wayPoints.isNotEmpty) {
      List wayPointsArray = [];
      for (var point in wayPoints) {
        wayPointsArray.add(point.location);
      }
      String wayPointsString = wayPointsArray.join('|');
      if (optimizeWaypoints) {
        wayPointsString = 'optimize:true|$wayPointsString';
      }
      params.addAll({"waypoints": wayPointsString});
    }
    Uri uri = Uri.https("maps.googleapis.com", "maps/api/directions/json", params);

    // print('GOOGLE MAPS URL: ' + url);
    var response = await http.get(uri);
    if (response.statusCode == 200) {
      var parsedJson = json.decode(response.body);
      result.status = parsedJson["status"];
      if (parsedJson["status"]?.toLowerCase() == statusOk &&
          parsedJson["routes"] != null &&
          parsedJson["routes"].isNotEmpty) {
        result.points = decodeEncodedPolyline(parsedJson["routes"][0]["overview_polyline"]["points"]);
        result.overviewPolyline = parsedJson["routes"][0]["overview_polyline"]["points"];
        result.distanceText = parsedJson["routes"][0]["legs"][0]['distance']['text'];
        result.distanceValue = parsedJson["routes"][0]["legs"][0]['distance']['value'];
        result.durationText = parsedJson["routes"][0]["legs"][0]['duration']['text'];
        result.durationValue = parsedJson["routes"][0]["legs"][0]['duration']['value'];
        result.endAddress = parsedJson["routes"][0]["legs"][0]['end_address'];
        result.startAddress = parsedJson["routes"][0]["legs"][0]['start_address'];
      } else {
        result.errorMessage = parsedJson["error_message"];
      }
    }
    return result;
  }

  ///decode the google encoded string using Encoded Polyline Algorithm Format
  /// for more info about the algorithm check https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  ///
  ///return [List]
  List<PointLatLng> decodeEncodedPolyline(String encoded) {
    List<PointLatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      PointLatLng p = PointLatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }
}
