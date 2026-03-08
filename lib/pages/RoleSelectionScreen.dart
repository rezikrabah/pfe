import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/clientpage.dart';
import 'package:test2/pages/fournisseurinfos.dart';
void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RoleSelectionScreen(),
    ),
);
    class RoleSelectionScreen extends StatefulWidget {
      const RoleSelectionScreen({super.key});
    
      @override
      State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
    }
    
    class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
      Widget roleCard({
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
        return Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  const  BoxShadow(
                    color: Colors.blue,
                    blurRadius: 40,
                  ),
                ],
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 60, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color:Color(0xFF0B3C49) ,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          backgroundColor: Color(0xFFEAFBFF),
          appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("choose your role",style: TextStyle(color: Color(0xFFEAFBFF)),),backgroundColor: Color(0xFF0B3C49),centerTitle: true,
          actions: [
            IconButton(
              icon: const     Icon(Icons.water_drop, size: 30,color: Color(0xFF1E88E5)),
              onPressed: () {

              },
            ),
          ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const  CircleAvatar(
                  radius: 35,
                  backgroundImage:  CachedNetworkImageProvider(
                    'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',
                  ),
                ),
                const  SizedBox(height: 20),
                const  Text(
                  "Vous êtes ?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3C49),
                  ),
                ),
                const SizedBox(height: 40),

                Row(
                  children: [
                    roleCard(
                      icon: Icons.person,
                      title: "Client",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => clientpage(),
                          ),
                        );
                      },
                    ),
                    roleCard(
                      icon: Icons.local_shipping,
                      title: "Fournisseur",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => fournisseurinfos(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    
    
