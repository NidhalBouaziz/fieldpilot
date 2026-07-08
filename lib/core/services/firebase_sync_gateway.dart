import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sync_operation.dart';
import 'firebase_bootstrap.dart';

class FirebaseSyncGateway {
  FirebaseSyncGateway(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> push(SyncOperation operation) async {
    if (!FirebaseBootstrap.configured) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final collectionName = switch (operation.entity) {
      SyncEntity.customer => 'customers',
      SyncEntity.visit => 'visits',
    };

    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection(collectionName)
        .doc(operation.entityId);
    if (operation.action == SyncAction.delete) {
      await ref.set({
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await ref.set({
      ...operation.payload,
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
