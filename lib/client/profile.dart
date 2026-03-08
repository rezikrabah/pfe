import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:test2/client/historique.dart';
import 'package:test2/client/suivi.dart';

import 'clientpage.dart';
import 'commandes.dart';
void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home:profile ()
    )
);
class profile extends StatefulWidget {
  const profile ({super.key});

  @override
  State<profile > createState() => _profileState();

}
int _currentScreenIndex =3;
List<Widget> _screens = [
  Scaffold(),
  Scaffold(),
  Scaffold(),
  Scaffold(),
];
class _profileState extends State<profile > {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("profile",style: TextStyle(color: Color(0xFFEAFBFF) ,fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2,),),backgroundColor: Color(0xFF0B3C49),centerTitle: true,
          actions: [
            IconButton(
              icon: const     Icon(Icons.water_drop, size: 30,color: Color(0xFF1E88E5)),
              onPressed: () {

              },
            ),
          ],
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [

            ],
          ),
        ),





        floatingActionButton: FloatingActionButton(
            backgroundColor:const Color(0xFF0B3C49),
            shape: const CircleBorder(),
            child:const Icon(CupertinoIcons.home, color: Colors.white,),
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
                  const Text('suivi',
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
                          builder: (context) => commandes(),
                        ),
                      );

                    },),
                  const  Text('commandes',
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
                    constraints:const BoxConstraints(),
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
              const SizedBox(width: 22,height: 80,),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(  icon:const Icon(CupertinoIcons.profile_circled,color: Color(0xFF0B3C49),size: 20,),
                    onPressed: (){

                    },
                  ),
                  const  Text('profile',
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
