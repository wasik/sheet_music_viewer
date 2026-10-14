import 'package:flutter/foundation.dart';

/// Bumped whenever sheets are added outside the normal list flow (shared files,
/// restored backups) so any open song/set lists can reload.
final ValueNotifier<int> libraryChanged = ValueNotifier(0);

void notifyLibraryChanged() => libraryChanged.value++;
