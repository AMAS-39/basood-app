import 'package:flutter/material.dart';
import '../../core/utils/pagination.dart';
import 'app_button.dart';

typedef PageFetcher<T> = Future<PaginationResult<T>> Function(String? cursor);

class PaginatedListView<T> extends StatefulWidget {
  final PageFetcher<T> fetchPage;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? emptyWidget;
  final Widget? errorWidget;

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyWidget,
    this.errorWidget,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final _items = <T>[];
  bool _loading = false;
  bool _hasMore = true;
  String? _cursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final result = await widget.fetchPage(_cursor);
      setState(() {
        _items.addAll(result.items);
        _hasMore = result.hasMore;
        _cursor = result.nextCursor;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _cursor = null;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget ?? 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Retry',
                onPressed: _refresh,
                isPrimary: false,
              ),
            ],
          ),
        );
    }

    if (_items.isEmpty && !_loading) {
      return widget.emptyWidget ?? 
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels > 
              notification.metrics.maxScrollExtent - 200) {
            _load();
          }
          return false;
        },
        child: ListView.builder(
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return widget.itemBuilder(context, _items[index]);
          },
        ),
      ),
    );
  }
}
