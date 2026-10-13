# Proxo Dynamic Form Pages

The dynamic form system is implemented with one fixed public Proxo template. Customers only provide the content: title, description, product image, field labels/options and button text. They do not control the layout or colors.

## Public URLs

Every saved form has a UUID:

```
https://<domain>/form/<FORM_UUID>
```

When the form is attached to a specific ad, the destination URL is:

```
https://<domain>/form/<FORM_UUID>?ad=<AD_UUID>
```

The database verifies that the ad belongs to the same user and that `pa_ads.form_id` matches the form before accepting an ad-attributed submission.

## Supabase

Applied to project `cojchkwssmasiejcgvbk`:

- `pa_forms` — form metadata/content.
- `pa_form_fields` — configurable labels and field types.
- `pa_form_submissions` — answers linked to the form and optional ad.
- `pa_ads.form_id` — selected form on an ad.
- `form-assets` — public product-image bucket; authenticated users can only write under their own user-id folder.
- RLS policies restrict customers to their own forms, fields and submissions.
- Ownership guard triggers prevent cross-account form/ad links.
- `pa_create_form(...)` — atomic authenticated form creation.
- `pa_attach_form_to_ad(ad_id, form_id)` — safely links a selected form to an owned ad and returns its destination path.
- `pa_get_public_form(form_id)` — public read RPC exposing only display-safe form data.
- `pa_submit_public_form(...)` — public submission RPC that validates required/type/select fields, derives the owner server-side, validates the optional ad link and stores only configured answers/attribution.

The migration is kept in `FORM_SYSTEM_SCHEMA.sql`.

## GitHub / Vercel

- `form.html` — the single fixed RTL form design.
- `form.js` — loads the UUID form and submits answers.
- `api/forms.js` — Vercel Function that proxies only through the hardened public Supabase RPCs.
- `vercel.json` — rewrites `/form/:id` to the fixed template.

No per-customer HTML file, GitHub commit or Vercel redeploy is needed. New forms are data rows in Supabase and become available immediately at their UUID URL.

The form API uses the Supabase publishable key only; it does not use a service-role secret. The checked-in publishable key is intentionally public and is safe because database access is limited by RPC grants, validation and RLS/guards.
