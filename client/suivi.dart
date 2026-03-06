import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/historique.dart';
import 'package:test2/client/profile.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'clientpage.dart';
import 'commandes.dart';

void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home:suivi ()
    )
);
class suivi extends StatefulWidget {
  const suivi ({super.key});

  @override
  State<suivi > createState() => _suiviState();

}
class _suiviState extends State<suivi> {
  final MapController mapController = MapController();

  Future<LatLng> getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  void goToUserLocation() async {
    LatLng userLoc = await getUserLocation();
    mapController.move(userLoc, 15);
  }

  @override
  Widget build(BuildContext context) {



    return Scaffold(
      body: FlutterMap(
        mapController: mapController, // SAME controller
        options: const MapOptions(
          initialCenter: LatLng(36.7538, 3.0588),
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.yourname.yourapp',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(36.7538, 3.0588),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin,
                    size: 40, color: Colors.red),
              ),
            ],
          ),

        ],
      ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: Color(0xFF0B3C49),
            shape: const CircleBorder(),
            child: Icon(CupertinoIcons.home, color: Colors.white,),
            onPressed:(){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => clientpage(),
                ),
              );
            }
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar:BottomAppBar(
          notchMargin: 8,
          height: 90,
color: Color(0xFF0B3C49),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon:
                  Icon(CupertinoIcons.map,color: Colors.white, size: 20,),

                    onPressed: (){

                    },
                  ),
                  Text('suivi',
                    style: TextStyle(
                      fontSize: 10,
                        color: Colors.white
                    ),
                  ),


                ],
              ),
              SizedBox(width: 35,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon: Icon(CupertinoIcons.cube_box_fill,color: Colors.white,size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => commandes(),
                        ),
                      );

                    },),
                  Text('commandes',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                        color: Colors.white
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 25,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(CupertinoIcons.clock,color: Colors.white,size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => historique(),
                        ),
                      );

                    },
                  ),
                  Text('historique',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 22,height: 80,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon: Icon(CupertinoIcons.profile_circled,color: Colors.white,size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => profile(),
                        ),
                      );
                    },
                  ),
                  Text('profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),

    );
  }
}
