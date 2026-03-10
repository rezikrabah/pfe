import 'package:flutter/material.dart';
import 'package:test2/pages/Homepage.dart';
import 'package:test2/pages/Login.dart';
import 'package:test2/pages/Loginpage.dart';
import 'package:test2/pages/createaccpage.dart';
import 'package:test2/pages/forgotpassword.dart';
import 'package:test2/pages/RoleSelectionScreen.dart';
import 'package:test2/pages/fournisseurinfos.dart';
import 'package:test2/pages/splashed_screen.dart';
void main() => runApp(MaterialApp(
  debugShowCheckedModeBanner: false,
  home: const AnimatedSplashScreenWidget(),
  routes: {
    '/Homepage': (context) => Homepage(),
    '/Login': (context) => Login(),
    '/Loginpage': (context) => Loginpage(),
    '/createaccpage': (context) => createaccpage(),
    '/forgotpassword': (context) => forgotpassword(),
    '/RoleSelectionScreen' :(context) => RoleSelectionScreen(),
    '/fournisseurinfos' :(context) => fournisseurinfos(),




  },
));
