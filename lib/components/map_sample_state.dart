import 'dart:async';
import 'dart:convert';
import 'package:fire_archive/components/NavBar.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:fire_archive/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import "dart:math" show asin, cos, pi, pow, sin, sqrt;
import 'package:geocoding/geocoding.dart';


class MapSampleState extends State<MapSample> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller =
      Completer(); // Controller for the Google Map.
  final TextEditingController _locationController =
      TextEditingController(); // Controller for the location text field.
  List<List<dynamic>>? locations; // List of hotspot locations.

  var _userPosition_lat, _userPosition_lng;
  bool _isDanger = false;

  // Constants
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(20.42796133580664, 80.885749655962),
    zoom: 4.5,
  );

  List<Marker> markers = <Marker>[
    const Marker(
      markerId: MarkerId('1'),
      // position: LatLng(20.42796133580664, 75.885749655962),
      infoWindow: InfoWindow(
          // title: 'Some Position',
          ),
    ),
  ];

  late String searchedLocation;

  // Searched location for the Google Map.

  List<List<dynamic>>? hotspots;

  @override
  void initState() {
    super.initState();

    var client = http.Client();
    client
        .get(Uri.parse(
            'https://firms.modaps.eosdis.nasa.gov/api/country/csv/3d27399c8e1faa664e38874ea2330ac5/VIIRS_SNPP_NRT/IND/1/2023-10-07'))
        .then((response) async {
      String data = response.body;
      List<List<dynamic>> res = const CsvToListConverter().convert(data);
      hotspots = res;

      setMarkers(hotspots!);
    });
  }

  List<Marker> spots = [];
  List<Marker> redSpots = [];

  void setMarkers(locations) async {

    var data = locations[0].join(',').toString();
    var dataList = data.split('\n');

    for (int i = 1; i < dataList.length; i++) {
      var newData = dataList[i].split(',');
      double latitude = double.parse(newData[1]);
      double longitude = double.parse(newData[2]);
      double brightness = double.parse(newData[3]);
      String place = '$latitude,$longitude';

      if (brightness > 355) {
        spots += <Marker>[
          Marker(
            markerId: MarkerId(i.toString()),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(
              title: '',
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onTap: () {
              _showMyDialog(latitude, longitude);
            },
          ),
        ];
        redSpots += <Marker>[
          Marker(
            markerId: MarkerId(i.toString()),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(
              title: '',
            ),
          ),
        ];
      } else if (brightness > 335) {
        spots += <Marker>[
          Marker(
            markerId: MarkerId(i.toString()),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(
              title: '',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
            onTap: () {
              _showMyDialog(latitude, longitude);
            },
          ),
        ];
      } else {
        spots += <Marker>[
          Marker(
            markerId: MarkerId(i.toString()),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(
              title: '',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
            onTap: () {
              _showMyDialog(latitude, longitude);
            },
          ),
        ];
      }
    }
    setState(() {
      markers.addAll(spots);
    });
  }

  Future<void> _showMyDialog(latitude, longitude) async {
    var client = http.Client();
    // ignore: prefer_typing_uninitialized_variables
    var data;
    await client
        .get(Uri.parse(
            'http://api.openweathermap.org/data/2.5/air_pollution?lat=$latitude&lon=$longitude&appid=7aec4f8d030b3228e06daddc0646ce4a'))
        .then((response) async {
      data = json.decode(response.body);
    });
    var aqi = data['list'][0]['main']['aqi'];
    data = data['list'][0]['components'];
    // ignore: use_build_context_synchronously
    return showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Details'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text('Air Quality Index: '),
                  Text('AQI : ${aqi}'),
                  Text('CO : ${data['co']}'),
                  Text('NO : ${data['no']}'),
                  Text('NO2 : ${data['no2']}'),
                  Text('O3 : ${data['o3']}'),
                  Text('SO2 : ${data['so2']}'),
                  Text('PM2_5 : ${data['pm2_5']}'),
                  Text('PM10 : ${data['pm10']}'),
                  Text('NH3 : ${data['nh3']}'),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Done'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  double degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  void _setSOS() {
    _userPosition_lat = degreesToRadians(15.6393300);
    _userPosition_lng = degreesToRadians(78.2842300);
    for (int i = 0; i < redSpots.length; i++) {
      double lat = degreesToRadians(redSpots[i].position.latitude);
      double lng = degreesToRadians(redSpots[i].position.longitude);

      double dLng = lng - _userPosition_lng;

      double dLat = lat - _userPosition_lat;

      double a = pow(sin(dLat / 2), 2) +
          cos(_userPosition_lat) * cos(lat) * pow(sin(dLng / 2), 2);

      double c = 2 * asin(sqrt(a));

      double r = 6371;

      double distance = c * r;

      if (distance < 10) {
        _isDanger = true;
      }
    }
  }


  @override
  void dispose() {
    // Dispose of resources here.
    _locationController.dispose();
    super.dispose();
  }

  Future<Position> getUserCurrentLocation() async {
    await Geolocator.requestPermission()
        .then((value) {})
        .onError((error, stackTrace) async {
      await Geolocator.requestPermission();
    });
    return await Geolocator.getCurrentPosition();
  }

 void searchLocation(String searchedLocation) async {
  try {
    List<Location> locations = await locationFromAddress(searchedLocation);

    if (locations.isNotEmpty) {
      Location firstLocation = locations.first;
      double latitude = firstLocation.latitude;
      double longitude = firstLocation.longitude;


      markers.add(
        Marker(
          markerId: const MarkerId("searchedLocation"),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: searchedLocation,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );

      // Move the camera to the searched location
      CameraPosition cameraPosition = CameraPosition(
        target: LatLng(latitude, longitude),
        zoom: 12,
      );

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      setState(() {});
    } else {
      // Handle the case where no location data is available
      print('No location data available for: $searchedLocation');
    }
  } catch (e) {
    print('Error searching location: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: NavBar(),
      appBar: myAppBar(),
      backgroundColor: Colors.white,
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  AppBar myAppBar() {
    return AppBar(
      title: const Text(
        'FireArchive🧯',
        style: TextStyle(
          color: Colors.black,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0.0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () {
          // Handle menu icon tap
          _scaffoldKey.currentState?.openDrawer();
        },
        // Handle menu
        child: Container(
          margin: const EdgeInsets.all(10),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/icons/menu-1.svg',
            height: 35,
            width: 35,
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('SOS'),
                    content: const Text('You are in a danger zone'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                });
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            alignment: Alignment.center,
            width: 37,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: _isDanger ? Colors.red : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBody() {
    return Column(
      children: [
        buildSearchRow(),
        Expanded(
          child: GoogleMap(
            mapType: MapType.normal,
            markers: Set<Marker>.of(markers),
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
        ),
      ],
    );
  }

  Widget buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(15),
                  hintText: 'Search Location',
                  hintStyle: const TextStyle(
                    color: Color(0xffDDDADA),
                    fontSize: 15,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      'assets/icons/loc-1.svg',
                      colorFilter: const ColorFilter.mode(
                        Color.fromARGB(255, 109, 107, 106),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  searchedLocation = value;
                  searchLocation(searchedLocation);
                },
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            searchLocation(searchedLocation);
          },
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }

  Widget buildFloatingActionButton() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 50.0),
    child: Tooltip(
      message: 'Current Location', // Tooltip text
      child: FloatingActionButton(
        onPressed: () async {
          getUserCurrentLocation().then((value) async {
            markers.add(
              Marker(
                markerId: const MarkerId("0"),
                position: LatLng(value.latitude, value.longitude),
                infoWindow: const InfoWindow(
                  title: 'My Current Location',
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
                onTap: () {
                  _showMyDialog(value.latitude, value.longitude);
                },
              ),
            );

            CameraPosition cameraPosition = CameraPosition(
              target: LatLng(value.latitude, value.longitude),
              zoom: 14,
            );

            _userPosition_lat = value.latitude;
            _userPosition_lng = value.longitude;

            final GoogleMapController controller = await _controller.future;
            controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
            setState(() {});

            _setSOS();
          });
        },
        child: const Icon(Icons.location_on), // Icon for current location
      ),
    ),
  );
}
}
