-- =============================================================================
-- MIGRAZIONE: Aggiunta RLS per utente su contracts e lessons
-- Eseguire nell'Editor SQL di Supabase (una sola volta)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 0: Verifica l'UUID del tuo utente (copialo per riferimento)
-- -----------------------------------------------------------------------------

SELECT id, email FROM auth.users LIMIT 10;

-- =============================================================================
-- ESEGUI PRIMA SOLO QUESTO BLOCCO (Step 1 e 2)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Aggiunta colonna user_id alle tabelle (nullable, senza NOT NULL)
-- -----------------------------------------------------------------------------

ALTER TABLE public.contracts
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- -----------------------------------------------------------------------------
-- 2. Aggiunta colonna is_paid a lessons (se non già presente)
-- -----------------------------------------------------------------------------

ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT FALSE;

-- =============================================================================
-- ESEGUI QUESTO BLOCCO SEPARATAMENTE (Step 3)
-- Sostituisci 'INSERISCI-QUI-IL-TUO-UUID' con l'UUID trovato nello Step 0
-- Esempio: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
-- =============================================================================

DO $$
DECLARE
  target_user_id UUID;
BEGIN
  -- Prende l'UUID del primo (e unico) utente registrato
  SELECT id INTO target_user_id FROM auth.users ORDER BY created_at LIMIT 1;

  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Nessun utente trovato in auth.users. Assicurati di aver registrato almeno un utente.';
  END IF;

  RAISE NOTICE 'Assegno i record all''utente: %', target_user_id;

  UPDATE public.contracts
    SET user_id = target_user_id
    WHERE user_id IS NULL;

  UPDATE public.lessons
    SET user_id = target_user_id
    WHERE user_id IS NULL;

  RAISE NOTICE 'Popolamento completato.';
END;
$$;

-- =============================================================================
-- ESEGUI QUESTO BLOCCO DOPO IL POPOLAMENTO (Step 4, 5, 6, 7)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4. Rimozione policy permissive esistenti (aperte a tutti)
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "Allow anonymous read/write on contracts" ON public.contracts;
DROP POLICY IF EXISTS "Allow anonymous read/write on lessons" ON public.lessons;

-- -----------------------------------------------------------------------------
-- 5. Nuove policy RLS per contratti: ogni utente vede solo i propri dati
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "contracts: select own" ON public.contracts;
DROP POLICY IF EXISTS "contracts: insert own" ON public.contracts;
DROP POLICY IF EXISTS "contracts: update own" ON public.contracts;
DROP POLICY IF EXISTS "contracts: delete own" ON public.contracts;

CREATE POLICY "contracts: select own" ON public.contracts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "contracts: insert own" ON public.contracts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "contracts: update own" ON public.contracts
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "contracts: delete own" ON public.contracts
  FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 6. Nuove policy RLS per lezioni: ogni utente vede solo le proprie lezioni
-- -----------------------------------------------------------------------------

DROP POLICY IF EXISTS "lessons: select own" ON public.lessons;
DROP POLICY IF EXISTS "lessons: insert own" ON public.lessons;
DROP POLICY IF EXISTS "lessons: update own" ON public.lessons;
DROP POLICY IF EXISTS "lessons: delete own" ON public.lessons;

CREATE POLICY "lessons: select own" ON public.lessons
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "lessons: insert own" ON public.lessons
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "lessons: update own" ON public.lessons
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "lessons: delete own" ON public.lessons
  FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 7. Verifica finale: conta i record senza user_id
-- -----------------------------------------------------------------------------

SELECT
  'contracts' AS tabella,
  COUNT(*) FILTER (WHERE user_id IS NULL) AS record_senza_user_id,
  COUNT(*) AS totale
FROM public.contracts
UNION ALL
SELECT
  'lessons',
  COUNT(*) FILTER (WHERE user_id IS NULL),
  COUNT(*)
FROM public.lessons;

-- =============================================================================
-- Fine migrazione
-- =============================================================================
