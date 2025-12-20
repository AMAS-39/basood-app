class PaginationResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? nextCursor;

  const PaginationResult({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });
}
