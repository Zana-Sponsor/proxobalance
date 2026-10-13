class AdCategoryOption {
  final String slug;
  final String label;

  const AdCategoryOption(this.slug, this.label);
}

/// Stable database slugs with Kurdish labels. Keep this list in sync with the
/// pa_ads category check constraint.
const List<AdCategoryOption> kAdCategories = <AdCategoryOption>[
  AdCategoryOption('cosmetics_beauty', 'کۆسمەتیک و جوانکاری'),
  AdCategoryOption('fashion_apparel', 'جل‌وبەرگ'),
  AdCategoryOption('electronics', 'ئەلیکترۆنیات'),
  AdCategoryOption('food_beverage', 'خواردن و خواردنەوە'),
  AdCategoryOption('home_living', 'ماڵ و کەلوپەل'),
  AdCategoryOption('automotive', 'ئۆتۆمبێل'),
  AdCategoryOption('services', 'خزمەتگوزاری'),
  AdCategoryOption('education', 'فێرکاری'),
  AdCategoryOption('games_apps', 'یاری و ئەپ'),
  AdCategoryOption('health_wellness', 'تەندروستی و خۆپارێزی'),
  AdCategoryOption('retail_ecommerce', 'فرۆشتن و ئۆنلاین شۆپ'),
  AdCategoryOption('other', 'هی تر'),
];

bool isSupportedAdCategory(String? slug) {
  if (slug == null || slug.isEmpty) return false;
  return kAdCategories.any((category) => category.slug == slug);
}

String adCategoryLabel(String? slug) {
  for (final category in kAdCategories) {
    if (category.slug == slug) return category.label;
  }
  return 'هی تر';
}
