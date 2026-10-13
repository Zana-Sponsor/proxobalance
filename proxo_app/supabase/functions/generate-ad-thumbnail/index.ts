import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

import { handleAdThumbnailRequest } from "../_shared/ad_thumbnail.ts";

serve(handleAdThumbnailRequest);
