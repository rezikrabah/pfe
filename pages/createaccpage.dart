import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:test2/pages/Loginpage.dart';
import 'package:test2/pages/RoleSelectionScreen.dart';
void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: createaccpage()
    )
);
class createaccpage extends StatefulWidget {
  const createaccpage({super.key});

  @override
  State<createaccpage> createState() => _createaccpageState();
}

class _createaccpageState extends State<createaccpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F2F36),
      appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("CREATE YOUR ACCOUNT",style: TextStyle(color: Color(0xFFEAFBFF) ,fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2,),),backgroundColor: Color(0xFF0C2A34),centerTitle: true,
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
            Container(
                width: double.infinity,
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(top: 10),
                child:
                CircleAvatar(
                  radius: 20,
                  backgroundImage: const CachedNetworkImageProvider(
                    'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',

                  ),

                )
            ),
            const Text('sign up',
  style:  const TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 25,
    fontWeight: FontWeight.w800,
  ),

),
            const Text('add your detailes to sign up',
              style:const  TextStyle(
                color: Color(0xFF9EC7CF),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),

            ),
SizedBox(height: 10,),
            //name
            TextFormField(
              decoration: InputDecoration(
                labelText: 'name',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'enter your name',
                hintStyle:   const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,

                ),
                prefixIcon:const  Icon(Icons.badge,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                ),
                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                ),
              ),
              style: TextStyle(
                color: Colors.white,
              ),
            ),
SizedBox(height: 10,),

            //mail
            TextFormField(
              decoration: InputDecoration(
                labelText: 'email',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'enter your email',
                hintStyle:  const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,

                ),
                prefixIcon:  const Icon(Icons.email,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),

                ),
                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2), // Change color here
                ),
              ),
              style:const  TextStyle(
                color: Colors.white,
              ),
              onChanged: (String value) {
              },
              validator: (value){
                return value!. isEmpty ? 'please enter your email':null;

              },
            ),
            SizedBox(height: 10,),


            // PHONE NUMBER
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'phone number',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'enter your phone number',
                hintStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,

                ),
                prefixIcon:const  Icon(Icons.phone,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5),
                ),
                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                ),
              ),
              style: TextStyle(
                color: Colors.white,
              ),
            ),
SizedBox(height: 10,),
            //password
            TextFormField(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'password',
                labelStyle:  const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'enter your password',
                hintStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon:const  Icon(Icons.password,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5), // Change color here
                ),

                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2), // Change color here
                ),
              ),
              onChanged: (String value) {
              },
              validator: (value){
                return value!. isEmpty ? 'please enter your password':null;

              },

            ),
 const SizedBox(height: 10),
            //CONFIRM PASSWORD
            TextFormField(
              style:const  TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'adresse',
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'please enter your adress',
                hintStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon:  const Icon(Icons.map,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Color(0xFFEAFBFF), width: 1.5), // Change color here
                ),

                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2), // Change color here
                ),
              ),
              onChanged: (String value) {
              },
              validator: (value){
                return value!. isEmpty ? 'please enter your password':null;
              },
            ),
           const  SizedBox(height: 10,),


            //sign up button
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
              child:TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoleSelectionScreen(),
                    ),
                  );
                },
                label:  const Text(
                  'sign up',style:TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.w600),
                ),
              ),

            ),
            const Text('already have account?',
              style:const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            TextButton(
              onPressed:(){
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Loginpage(),
                  ),
                );
              },

              child: const Text('login'
                  ,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ),
          ],

        ),
      ),

    );
  }
}
