BEGIN;

CREATE TABLE IF NOT EXISTS public.ex_order_user_hides (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.ex_orders(id) ON DELETE CASCADE,
  hidden_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, order_id)
);
CREATE INDEX IF NOT EXISTS ex_order_user_hides_order_id_idx
  ON public.ex_order_user_hides (order_id);

ALTER TABLE public.ex_order_user_hides ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.ex_order_user_hides FROM PUBLIC, anon;
GRANT SELECT, INSERT, DELETE ON TABLE public.ex_order_user_hides TO authenticated;

DO $policies$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='ex_order_user_hides'
      AND policyname='ex_order_user_hides_select_own'
  ) THEN
    CREATE POLICY ex_order_user_hides_select_own
      ON public.ex_order_user_hides FOR SELECT TO authenticated
      USING (user_id=auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='ex_order_user_hides'
      AND policyname='ex_order_user_hides_insert_own'
  ) THEN
    CREATE POLICY ex_order_user_hides_insert_own
      ON public.ex_order_user_hides FOR INSERT TO authenticated
      WITH CHECK (
        user_id=auth.uid()
        AND EXISTS (
          SELECT 1 FROM public.ex_orders o
          WHERE o.id=order_id AND o.user_id=auth.uid()
        )
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='ex_order_user_hides'
      AND policyname='ex_order_user_hides_delete_own'
  ) THEN
    CREATE POLICY ex_order_user_hides_delete_own
      ON public.ex_order_user_hides FOR DELETE TO authenticated
      USING (user_id=auth.uid());
  END IF;
END;
$policies$;

COMMIT;
