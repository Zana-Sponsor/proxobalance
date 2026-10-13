// Backwards-compatible entry point. New Flutter code invokes
// `generate-ad-thumbnail`; keeping this alias prevents older app builds from
// calling the accidentally copied notification handler that used to live here.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

import { handleAdThumbnailRequest } from "../_shared/ad_thumbnail.ts";

serve(handleAdThumbnailRequest);
