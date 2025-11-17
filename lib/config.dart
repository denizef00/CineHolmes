import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  //  TMDB API anahtarı
  static String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';
/*
  //  ACRCloud yapılandırması
  static String get acrHost => dotenv.env['ACRCLOUD_HOST'] ?? '';
  static String get acrAccessKey => dotenv.env['ACRCLOUD_ACCESS_KEY'] ?? '';
  static String get acrAccessSecret => dotenv.env['ACRCLOUD_SECRET_KEY'] ?? '';}
  */