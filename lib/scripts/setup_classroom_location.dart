/// Quick setup script to configure classroom coordinates
///
/// This script will help you configure coordinates for a classroom.
/// Run this using: dart run lib/scripts/setup_classroom_location.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import '../firebase_options.dart';

void main() async {
  print('╔════════════════════════════════════════════════════╗');
  print('║   Classroom Location Setup Script                ║');
  print('╚════════════════════════════════════════════════════╝\n');

  // Initialize Firebase
  print('[1/4] Initializing Firebase...');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('✓ Firebase initialized\n');

  final firestore = FirebaseFirestore.instance;

  // List all classes
  print('[2/4] Fetching all classes from Firestore...');
  final classesSnapshot = await firestore.collection('classes').get();

  if (classesSnapshot.docs.isEmpty) {
    print('✗ No classes found in database. Please create a class first.');
    exit(1);
  }

  print('✓ Found ${classesSnapshot.docs.length} class(es)\n');

  // Display classes
  print('Available classes:');
  for (var i = 0; i < classesSnapshot.docs.length; i++) {
    final doc = classesSnapshot.docs[i];
    final data = doc.data();
    print('  ${i + 1}. ${data['name']} (${data['code']}) - ID: ${doc.id}');
  }

  // Get user input
  print(
    '\n[3/4] Enter the number of the class to configure (or press Enter to configure the first one):',
  );
  final input = stdin.readLineSync();
  final selectedIndex = (input == null || input.isEmpty)
      ? 0
      : int.tryParse(input)! - 1;

  if (selectedIndex < 0 || selectedIndex >= classesSnapshot.docs.length) {
    print('✗ Invalid selection');
    exit(1);
  }

  final selectedClass = classesSnapshot.docs[selectedIndex];
  final classData = selectedClass.data();
  print('\n✓ Selected: ${classData['name']}\n');

  // Configure coordinates
  print('[4/4] Configuring classroom location...');

  // Your provided coordinates
  final latitude = 22.601721733113674;
  final longitude = 72.81788708731466;
  final radiusMeters = 50.0; // 50 meters for testing

  print('   Latitude:  $latitude');
  print('   Longitude: $longitude');
  print('   Radius:    $radiusMeters meters');

  await firestore.collection('classes').doc(selectedClass.id).update({
    'latitude': latitude,
    'longitude': longitude,
    'allowedRadiusMeters': radiusMeters,
  });

  print('\n✓ Classroom location configured successfully!');
  print('\n╔════════════════════════════════════════════════════╗');
  print('║                    SUCCESS!                        ║');
  print('╠════════════════════════════════════════════════════╣');
  print('║ Classroom: ${classData['name'].toString().padRight(38)}║');
  print('║ Coordinates: $latitude, $longitude');
  print('║ Allowed radius: $radiusMeters meters               ║');
  print('║                                                    ║');
  print('║ Students must be within $radiusMeters meters of this    ║');
  print('║ location to mark attendance.                      ║');
  print('╚════════════════════════════════════════════════════╝\n');

  exit(0);
}
