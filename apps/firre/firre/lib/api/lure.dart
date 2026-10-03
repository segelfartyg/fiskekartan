/// A lure from the user's lure box (GET /api/lures). Only what the catch
/// form needs: picking one fills in the bait and links the catch to it.
class Lure {
  Lure.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String;

  final String id;
  final String title;
}
