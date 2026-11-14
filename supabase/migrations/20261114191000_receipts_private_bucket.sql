-- Step 2 of the receipts fix. Apply ONLY after the v39 website is live
-- (it shows receipts through signed links: assets/js/receipt-access.js,
-- and Telegram gets a signed link from api-handlers/notify-order.js).
-- After this, a receipt address opens only for its owner or for staff.
update storage.buckets set public = false where id = 'receipts';
