import 'package:flutter/material.dart';
import 'package:test2/pages/Loginpage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:test2/pages/createaccpage.dart';
import 'package:test2/client/clientpage.dart';
import 'package:test2/pages/fournisseurinfos.dart';


void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Login()
    )
);
class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  @override
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Color(0xFF0C2A34),
      appBar:
      AppBar(
        backgroundColor: Color(0xFF0C2A34),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const  Text(
              'LOG in ',
              style: TextStyle(
                color: Color(0xFF4ECDC4),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),

          ],
        ),

        actions: [
          Icon(Icons.water_drop, color: Color(0xFF4ECDC4), size: 28),

          const  SizedBox(width: 10),
        ],
      ),

body: SingleChildScrollView(
  child: SizedBox(
    width: double.infinity,
    height: MediaQuery.of(context).size.height,
 child:  Stack(
   children: [
     Positioned.fill(
       child: CachedNetworkImage(
         imageUrl: 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?q=80&w=774&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
         fadeInDuration: Duration(milliseconds: 200),
         fit: BoxFit.cover,
         placeholder: (context, url) => CircularProgressIndicator(),
         errorWidget: (context, url, error) =>const Icon(Icons.error),
       ),
     ),
    Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      padding:const EdgeInsets.only(top: 100),
      child:
      const   CircleAvatar(
        radius: 35,
        backgroundImage:CachedNetworkImageProvider(
          'https://static.vecteezy.com/system/resources/previews/019/952/881/original/oil-tanker-icon-design-free-vector.jpg',
        ),

    ),
    ),
Padding(
  padding:const EdgeInsets.only(top: 200),
  child: Column(
    children: [
      const  Text(
          'welcome to the first water delevry application',
        style: TextStyle(color: Color(0xFFB8E3F0),fontWeight: FontWeight.w900,fontSize:14),
      ),
      const  SizedBox(height: 20,),
    Container(
    height: 56,
    alignment: Alignment.center,
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
    child: TextButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Loginpage(),
          ),
        );
      },
      label: const Text(
        'LOGIN',style: TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.w600),
      ),
    ),
),
      const  SizedBox(height: 20,),
    Container(
      height: 56,
      alignment: Alignment.center,
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
      child:  TextButton.icon(
        onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => createaccpage(),
),
);
},
  label:const Text(
    'Create an account',style: TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.w600),
  ),
),
    ),
    ],
  )
),
  ],
),
  ),
    ),
    );
  }
}
