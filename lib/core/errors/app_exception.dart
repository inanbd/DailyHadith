/// Failures the UI knows how to render.
///
/// Data-layer errors are converted into one of these so screens never have to
/// interpret a raw platform or database exception.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// The requested collection has no readable text on this device.
class DatasetUnavailableException extends AppException {
  const DatasetUnavailableException(this.collectionId, {super.cause})
      : super('No hadith data is installed for this collection.');

  final String collectionId;
}

/// The catalog itself could not be read — the app cannot list any books.
class CatalogUnavailableException extends AppException {
  const CatalogUnavailableException({super.cause})
      : super('The hadith library could not be loaded.');
}

/// Local storage failed.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// The content source returned something that does not match the expected
/// schema. Kept distinct so a bad import is not reported as "no data".
class ContentFormatException extends AppException {
  const ContentFormatException(super.message, {super.cause});
}
