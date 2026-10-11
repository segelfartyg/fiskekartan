import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../api/api_client.dart';

/// A catch photo for the detail sheet, from its backend-relative, signed
/// URL (`/catch-images/...?exp=…&sig=…`).
///
/// The photos are camera originals (often 4032×3024, ~3 MB), so they're kept
/// on disk across app starts and decoded at the sheet's width instead of
/// full size — a full-size decode is ~50 MB, which pushes everything else out
/// of Flutter's in-memory image cache. Prefetching and the sheet must both go
/// through here so they share one cache entry.
ImageProvider catchPhoto(BuildContext context, String path) {
  // The widest a photo is shown: a lone photo fills the sheet's width.
  final width =
      (MediaQuery.sizeOf(context).width - 48) *
      MediaQuery.devicePixelRatioOf(context);
  return ResizeImage(
    CachedNetworkImageProvider(
      apiUrl(path),
      // Cached by the photo itself, not its signature, which changes daily.
      cacheKey: Uri.parse(path).path,
    ),
    width: width.round(),
  );
}
