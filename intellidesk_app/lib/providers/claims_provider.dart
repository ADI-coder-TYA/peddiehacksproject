import 'package:flutter/foundation.dart';
import '../models/claim.dart';

class ClaimsProvider extends ChangeNotifier {
  final List<Claim> _claims = [];

  List<Claim> get claims => List.unmodifiable(_claims);

  void addClaim(Claim claim) {
    _claims.add(claim);
    notifyListeners();
  }

  void updateClaimStatus(String id, String status) {
    final idx = _claims.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _claims[idx] = Claim(
        id: _claims[idx].id,
        userId: _claims[idx].userId,
        category: _claims[idx].category,
        amount: _claims[idx].amount,
        status: status,
        submittedAt: _claims[idx].submittedAt,
      );
      notifyListeners();
    }
  }
}
