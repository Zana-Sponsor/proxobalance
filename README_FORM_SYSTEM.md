# Proxo Dynamic Form Pages

This branch prepares one fixed public form template for every customer-created form.

## Public URL

A saved form uses its own UUID:

```
https://<domain>/form/<FORM_UUID>
```

When the form is attached to a specific ad, use:

```
https://<domain>/form/<FORM_UUID>?ad=<AD_UUID>
```

The server verifies that `pa_ads.form_id = FORM_UUID` and that the ad belongs to the same owner before saving an ad-attributed submission.

## Architecture

- `form.html` — one fixed Proxo design. Customers do not change colors/layout.
- `form.js` — loads title, description, product image and fields from the API.
- `api/forms.js` — public GET + verified POST endpoint.
- `pa_forms` — one row per customer-created form.
- `pa_form_fields` — labels/fields belonging to a form.
- `pa_form_submissions` — answers, linked to `form_id` and optionally `ad_id`.
- `pa_ads.form_id` — links an ad to the selected form.
- `FORM_SYSTEM_SCHEMA.sql` — database migration prepared for later review/application.

No HTML file is generated per customer. GitHub/Vercel keep one template; Supabase data determines what appears at each UUID URL.

## Vercel variables

The public form API intentionally uses separate variables from the existing Exchange site configuration:

```
PROXO_SUPABASE_URL=https://cojchkwssmasiejcgvbk.supabase.co
PROXO_SUPABASE_SERVICE_ROLE_KEY=<server-only service role key>
```

Never expose the service role key in browser JavaScript or commit it to GitHub.

Until the database migration is applied and these variables are configured, `/api/forms` returns a safe `forms_not_configured` response.
