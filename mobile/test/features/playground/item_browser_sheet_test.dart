import 'package:dio/dio.dart';
import 'package:fashion_app/core/models/catalog_filter_options.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/features/discover/data/catalog_repository.dart';
import 'package:fashion_app/features/playground/ui/widgets/item_browser_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Studio shop catalog loads the full backend catalog and categories',
    (tester) async {
      final repository = _FakeCatalogRepository(
        categories: const ['top', 'bag', 'activewear'],
      );

      await tester.pumpWidget(
        _TestHarness(
          repository: repository,
          child: ItemBrowserSheet(
            updateSlotOnSelect: false,
            onItemSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.searchPageCalls, [(category: null, offset: 0)]);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Bag'), findsOneWidget);
      expect(find.text('Activewear'), findsOneWidget);
    },
  );

  testWidgets('Slot browser still defaults to the slot category', (
    tester,
  ) async {
    final repository = _FakeCatalogRepository(
      categories: const ['top', 'bag', 'activewear'],
    );

    await tester.pumpWidget(
      _TestHarness(
        repository: repository,
        child: ItemBrowserSheet(
          type: SlotType.bag,
          onItemSelected: (_) {},
        ),
      ),
      );
      await tester.pumpAndSettle();

    expect(repository.searchPageCalls, [(category: 'bag', offset: 0)]);
    expect(find.text('All'), findsNothing);
    expect(find.text('Bag'), findsOneWidget);
  });
}

class _TestHarness extends StatelessWidget {
  const _TestHarness({
    required this.repository,
    required this.child,
  });

  final CatalogRepository repository;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({
    this.categories = const [],
  }) : super(Dio());

  final List<String> categories;
  final List<({String? category, int offset})> searchPageCalls = [];

  @override
  Future<CatalogFilterOptions> fetchFilterOptions() async {
    return CatalogFilterOptions(
      categories: categories,
      brands: const ['Mango'],
      genders: const ['women', 'men'],
      fits: const ['regular'],
      colors: const ['Black'],
      styleTags: const ['minimal'],
      subtypes: const ['shirt'],
      subtypesByCategory: const {
        'top': ['shirt'],
        'bag': ['shoulder bag'],
      },
    );
  }

  @override
  int get catalogPageSize => 100;

  @override
  Future<({List<CatalogItem> items, int total})> searchPage({
    String? category,
    String? subtype,
    String? color,
    String? brand,
    String? gender,
    String? style,
    String? fit,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    searchPageCalls.add((category: category, offset: offset));
    return (items: const <CatalogItem>[], total: 0);
  }
}
