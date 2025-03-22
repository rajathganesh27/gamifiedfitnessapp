// lib/model/exercise_data_model.dart
import 'package:flutter/material.dart';

enum ExerciseType { PushUps, Squats, DownwardDogPlank, JumpingJack }

class ExerciseDataModel {
  final String title;
  final String image;
  final Color color;
  final ExerciseType type;

  ExerciseDataModel({
    required this.title,
    required this.image,
    required this.color,
    required this.type,
  });
}
