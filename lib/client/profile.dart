import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test2/client/historique.dart';
import 'package:test2/client/suivi.dart';
import 'package:test2/pages/Loginpage.dart';

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
        backgroundColor: const Color(0xFFF0F4FF),
        resizeToAvoidBottomInset: true,
        appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("profile",style: TextStyle(color: Color(0xFFEAFBFF) ,fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2,),),backgroundColor: Color(0xFF0B3C49),centerTitle: true,
          actions: [
            IconButton(
              icon: const     Icon(Icons.settings, size: 30,color: Color(0xFF1E88E5)),
              onPressed: () {

              },
            ),
          ],
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [
Padding(
  padding: const EdgeInsets.only(top: 80.0,left: 12,),
    child: CircleAvatar(
      radius: 30,
      backgroundColor:const Color(0xFF6FB6C3),
      child: Icon(Icons.person, color: Colors.white, size: 30),
    ),
  
),
              SizedBox(height: 30,),
              Container(
                height: 490,
                width: 350,
                margin: const EdgeInsetsDirectional.only(top: 40),
                decoration: BoxDecoration(
                  color:const Color(0xFF1F6F7F),
                  borderRadius: BorderRadius.circular(20),
              ),
                child: GestureDetector(
              child:   Column(
                  children: [
                    Text('paramètre',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                    ),
                    // --------------information personneles--------------------
                      Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 10,bottom: 10),
                        margin: const EdgeInsetsDirectional.only(top: 40),
                      decoration: BoxDecoration(
                        color:const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child:Row(
                        children: [
                          Icon(Icons.account_box,size: 30,color: Colors.white,),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => profile(),
                                ),
                              );
                            },
                            label:
                            const   Text('information personneles',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const  SizedBox(width:60,),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                const    BoxShadow(
                                  color: Colors.blue,
                                  blurRadius: 50,
                                ),
                              ],
                            ),

                            child: IconButton(  icon:const Icon(CupertinoIcons.arrow_right,color: Colors.white,size: 20,),
                              onPressed: (){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => profile(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    //-------------PAIMENET----------------------
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 10,bottom: 10),
                      margin: const EdgeInsetsDirectional.only(top: 40),
                      decoration: BoxDecoration(
                        color:const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child:Row(
                        children: [
                          Icon(Icons.paid_outlined,size: 30,color: Colors.white,),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => profile(),
                                ),
                              );
                            },
                            label:
                            const   Text('PAIMENETS & FACTURATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const  SizedBox(width:30,),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                const    BoxShadow(
                                  color: Colors.blue,
                                  blurRadius: 50,
                                ),
                              ],
                            ),

                            child: IconButton(  icon:const Icon(CupertinoIcons.arrow_right,color: Colors.white,size: 20,),
                              onPressed: (){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => profile(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    //-----------------notification-----------------------
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 10,bottom: 10),
                      margin: const EdgeInsetsDirectional.only(top: 40),
                      decoration: BoxDecoration(
                        color:const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child:Row(

                        children: [
                          Icon(Icons.notifications,size: 30,color: Colors.white,),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => profile(),
                                ),
                              );
                            },
                            label:
                            const   Text('NOTIFICATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const  SizedBox(width:115,),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                const    BoxShadow(
                                  color: Colors.blue,
                                  blurRadius: 50,
                                ),
                              ],
                            ),

                            child: IconButton(  icon:const Icon(CupertinoIcons.arrow_right,color: Colors.white,size: 20,),
                              onPressed: (){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => profile(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    //--------------langue-----------------------------
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 10,bottom: 10),
                      margin: const EdgeInsetsDirectional.only(top: 40),
                      decoration: BoxDecoration(
                        color:const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child:Row(
                        children: [
                          Icon(Icons.language,size: 30,color: Colors.white,),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => profile(),
                                ),
                              );
                            },
                            label:
                            const   Text('LANGUE\nfrançais',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const  SizedBox(width:150,),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                const    BoxShadow(
                                  color: Colors.blue,
                                  blurRadius: 50,
                                ),
                              ],
                            ),

                            child: IconButton(  icon:const Icon(CupertinoIcons.arrow_right,color: Colors.white,size: 20,),
                              onPressed: (){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => profile(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
    ),

                ),
               SizedBox(height: 20,),
               Container(
                height: 56,

                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed:(){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Loginpage(),
                      ),
                    );
                  },
                  child: const Text(''
                      'SE DECONNECTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),





        floatingActionButton: FloatingActionButton(
            backgroundColor:const Color(0xFF0B3C49),
            shape: const CircleBorder(),
            mini: true,
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
