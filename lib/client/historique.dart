import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/profile.dart';
import 'package:test2/client/suivi.dart';

import '../services/api_service.dart';
import 'clientpage.dart';
import 'commandes.dart';
void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: historique()
    )
);
class historique extends StatefulWidget {
  const historique({super.key});

  @override
  State<historique> createState() => _historiqueState();

}
int _currentScreenIndex =3;
List<Widget> _screens = [
  const  Scaffold(),
  const Scaffold(),
  const Scaffold(),
  const Scaffold(),
];
class _historiqueState extends State<historique> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(

        resizeToAvoidBottomInset: true,
        appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),
          centerTitle: true,
          backgroundColor:const Color(0xFF0C2A34),
          elevation: 0,
          title:
          const  Text("historique",
          style: TextStyle(color: Color(0xFFEAFBFF) ,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,),),

          actions: [
            const  CircleAvatar(
              backgroundColor: Color(0xFF1a5a6a),
              radius: 18,
              child: Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ],
        ),


        body: SingleChildScrollView(
          child:
          Column(
            children: [

              Container(
                height: 500,
                width: 350,
                margin: const EdgeInsetsDirectional.only(top: 40),
                decoration: BoxDecoration(
                  color:const Color(0xFF0B3C49),
                  borderRadius: BorderRadius.circular(20),

                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('tout les commandes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,

                          ),
                        ),


                      ],
                    ),
                    const  SizedBox(height: 40,),
                    // --------------------------1ere------------------------------
                    Row(
                      children: [
                        const   Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                        const SizedBox(width: 10,),

                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: '1 citerne x500L',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: '\n25 Décembre 2025',
                                style: TextStyle(
                                  color: Color(0xFF4ECDC4),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: '\n fournisseur ramzy naoui',
                                style: TextStyle(
                                  color: Colors.lightBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),  const SizedBox(width: 21,),

                        Container(height: 50, width: 2, color: Colors.white24),

                        const   SizedBox(width: 60,),
                        const  Text('6000DA ✓',
                          style: TextStyle(
                            color: Colors.green,

                          ),
                        ),

                      ],
                    ),

                    // ---------------------------2EME-------------------------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                            const  SizedBox(width: 10,),
                            RichText(
                              text:const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '1 citerne x400L',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n02 Janvier 2025',
                                    style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n fournisseur rezik rabah',
                                    style: TextStyle(
                                      color: Colors.lightBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),

                            ), const  SizedBox(width: 26,),

                            Container(height: 60, width: 2, color: Colors.white24),
                            const  SizedBox(width: 60,),
                            const Text('5000DA ✓',
                              style: TextStyle(
                                color: Colors.green,

                              ),
                            ),

                          ],
                        )
                      ],
                    ),
                    // ---------------------------3EME-------------------------
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const  Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                            const SizedBox(width: 10,),

                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '1 citerne x200L',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n 02 Décembre 2024',
                                    style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n fournisseur loucif rafik',
                                    style: TextStyle(
                                      color: Colors.lightBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),  const SizedBox(width: 27.3,),

                            Container(height: 60, width: 2, color: Colors.white24),
                            const  SizedBox(width: 60,),
                            const  Text('3000DA ✓',
                              style: TextStyle(
                                color: Colors.green,

                              ),
                            ),

                          ],
                        ),
                        // ---------------------------4EME-------------------------
                        Row(
                          children: [
                            const  Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                            const SizedBox(width: 10,),

                            RichText(
                              text:const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '1 citerne x800L',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n 22 avril 2024',
                                    style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n fournisseur mohammed ali',
                                    style: TextStyle(
                                      color: Colors.lightBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),

                                ],
                              ),
                            ), const  SizedBox(width: 9.7,),

                            Container(height: 60, width: 2, color: Colors.white24),
                            const  SizedBox(width: 60,),
                            const  Text('7500DA ✓',
                              style: TextStyle(
                                color: Colors.green,

                              ),
                            ),

                          ],
                        ),
                        // ---------------------------5EME-------------------------
                        Row(
                          children: [
                            const  Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                            const  SizedBox(width: 10,),

                            RichText(
                              text:const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '1 citerne x500L',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n 15 november 2023',
                                    style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n fournisseur hichem khelifi',
                                    style: TextStyle(
                                      color: Colors.lightBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ), const  SizedBox(width: 12,),

                              Container(height: 60, width: 2, color: Colors.white24),
                            const  SizedBox(width: 60,),
                            const  Text('5500DA ✓',
                              style: TextStyle(
                                color: Colors.green,

                              ),
                            ),

                          ],
                        ),
                        // ---------------------------6EME-------------------------
                        Row(
                          children: [
                            const  Icon(Icons.local_shipping_sharp, color: Color(0xFF4ECDC4), size: 28),
                            const SizedBox(width: 10,),

                            RichText(
                              text:const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '1 citerne x1000L',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n3 janvier 2023',
                                    style: TextStyle(
                                      color: Color(0xFF4ECDC4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '\n fournisseur islam madani',
                                    style: TextStyle(
                                      color: Colors.lightBlue,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),  const SizedBox(width: 16,),

                            Container(height: 60, width: 2, color: Colors.white24),
                            const   SizedBox(width: 60,),
                            const  Text('8000DA ✓',
                              style: TextStyle(
                                color: Colors.green,

                              ),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ],
                ),

              ),
            ],
          ),

        ),


        floatingActionButton: FloatingActionButton(
            backgroundColor:const Color(0xFF0B3C49),
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

          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon:
                  const  Icon(CupertinoIcons.map,color: Color(0xFF0B3C49), size: 20,),

                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => suivi(),
                        ),
                      );
                    },
                  ),
                  const   Text('suivi',
                    style: TextStyle(
                      fontSize: 10,
                      color:  Color(0xFF0B3C49),
                    ),
                  ),


                ],
              ),
              const   SizedBox(width: 35,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon:const Icon(CupertinoIcons.cube_box_fill,color: Color(0xFF0B3C49),size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => commandes(clientId: int.tryParse(ApiService.userId ?? '0') ?? 0,),
                        ),
                      );

                    },),
                  const Text('commandes',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color:  Color(0xFF0B3C49),
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
                    padding: EdgeInsets.zero, // Remove padding
                    constraints: BoxConstraints(),
                    icon:const Icon(CupertinoIcons.clock,color: Color(0xFF0B3C49),size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => historique(),
                        ),
                      );

                    },
                  ),
                  const  Text('historique',
                    style: TextStyle(
                      color:  Color(0xFF0B3C49),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              const  SizedBox(width: 22,height: 80,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon:const Icon(CupertinoIcons.profile_circled,color: Color(0xFF0B3C49),size: 20,),
                    onPressed: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => profile(),
                        ),
                      );
                    },
                  ),
                  const   Text('profile',
                    style: TextStyle(
                      color:  Color(0xFF0B3C49),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

            ],
          ),
        )
    );
  }
}
