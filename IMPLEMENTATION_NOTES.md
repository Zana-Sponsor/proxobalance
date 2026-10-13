# Weekly results + ad categories

This repository is a transfer bundle. Copy the files to the matching paths in
the Flutter project:

| Repository file | Flutter project path |
| --- | --- |
| ad_create_screen.dart | lib/screens/ad_create_screen.dart |
| home_screen.dart | lib/screens/home_screen.dart |
| ad_categories.dart | lib/services/ad_categories.dart |
| best_metrics_service.dart | lib/services/best_metrics_service.dart |
| best_metric_card.dart | lib/widgets/best_metric_card.dart |
| best_metrics_home_section.dart | lib/widgets/best_metrics_home_section.dart |
| best_metrics_screen.dart | lib/screens/best_metrics_screen.dart |
| 20260914_weekly_results_categories.sql | supabase/migrations/20260914_weekly_results_categories.sql |

Required packages already used by the supplied app files:

- solar_iconkit
- cached_network_image
- url_launcher
- supabase_flutter

## Admin curation

The section only shows rows selected by an admin for the current Baghdad week
(Monday through Sunday). Example:

```sql
update public.pa_ads
set is_featured = true,
    featured_week_start =
      date_trunc('week', timezone('Asia/Baghdad', now()))::date,
    featured_sort = 1
where id = '<AD_UUID>';
```

Use a distinct `featured_sort` value for each row to control ranking.
Unfeature an ad with:

```sql
update public.pa_ads
set is_featured = false
where id = '<AD_UUID>';
```

The sync trigger copies only display-safe metrics to
`pa_featured_ads_public`. The Flutter query deliberately does not select or
render the ad title.

## Backward-compatible rollout

The new Flutter form requires a category. For installed app versions that do
not yet send the field, the server stores `other` so ad creation and FastPay
remain available during rollout. Non-empty unknown slugs are still rejected as
`INVALID_CATEGORY`.
