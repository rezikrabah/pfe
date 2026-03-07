import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'forgotpassword.dart';
import 'RoleSelectionScreen.dart';

void main() => runApp(
    MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Loginpage()
    )
);
class Loginpage extends StatefulWidget {

  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0C2A34),
      appBar: AppBar( iconTheme: const IconThemeData(color: Color(0xFFFFFFFF),),title: const Text("log your account",style: TextStyle(color: Color(0xFFEAFBFF)),),backgroundColor: Color(0xFF0B3C49),centerTitle: true,
        actions: [
          IconButton(
            icon: const     Icon(Icons.water_drop, size: 30,color: Color(0xFF1E88E5)),
            onPressed: () {},
          ),
        ],
      ),
        body: SingleChildScrollView(
          child:SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,

        child:Stack(
              children: [
                Positioned.fill(
              child:
               CachedNetworkImage(
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
                    padding:const EdgeInsets.only(top: 50),
                    child:
                    const   CircleAvatar(
                      radius: 30,
                      backgroundImage: CachedNetworkImageProvider(
                        'https://img.freepik.com/premium-vector/water-vector-logo-design-white-background_1277164-15228.jpg',
                      ),
                    )
                ),
                const SizedBox(height: 50,),
Padding(
  padding: const EdgeInsets.only(top: 150,left: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text('LOGIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,

        ),
      ),
     const Text('add your detailes to login',
        style: TextStyle(
          color: Color(0xFFB8E3F0),
          fontSize:14,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10,),
            //-------------email---------------------
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'email',
                labelStyle:  const TextStyle(
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
                prefixIcon:const Icon(Icons.email,color: Colors.white,),
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
              style: const TextStyle(
                color: Colors.white,
              ),
              onChanged: (String value) {
              },
              validator: (value){
                return value!. isEmpty ? 'please enter your email':null;

              },
            ),
      const  SizedBox(height: 30.0),

//-------------------------password------------------------------

            TextFormField(
              keyboardType: TextInputType.visiblePassword,
              style:  const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'password',
                labelStyle:   const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                hintText: 'enter your password',
                hintStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon:const Icon(Icons.password,color: Colors.white,),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color:const Color(0xFFEAFBFF), width: 1.5),
                ),

                // Border when focused
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
                ),
              ),
              onChanged: (String value) {
              },
              validator: (value){
                return value!. isEmpty ? 'please enter your password':null;

              },

            ),
      const SizedBox(height: 20,),

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
              child: TextButton(
                  onPressed:(){
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoleSelectionScreen(),
                      ),
                    );
                  },
                child: const Text(''
                    'log in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
]

  ),
),
          ],
        ),
          ),
    ),
    );

  }
}
