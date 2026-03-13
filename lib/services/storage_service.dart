// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadPhoto({
    required File file,
    required String familyId,
    required String userId,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final path =
          'families/$familyId/photos/${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref(path);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload photo error: $e');
      return null;
    }
  }

  Future<String?> uploadFile({
    required File file,
    required String familyId,
    required String userId,
    required String fileName,
  }) async {
    try {
      final path =
          'families/$familyId/files/${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref(path);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload file error: $e');
      return null;
    }
  }

  Future<String?> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    try {
      final ext = file.path.split('.').last;
      final path = 'avatars/$userId.$ext';
      final ref = _storage.ref(path);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload avatar error: $e');
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Delete file error: $e');
    }
  }
}
