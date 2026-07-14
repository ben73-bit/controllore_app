-- Creazione tabella contracts
CREATE TABLE IF NOT EXISTS public.contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    contract_number TEXT,
    hourly_rate NUMERIC(10, 2) NOT NULL,
    total_hours_limit NUMERIC(10, 2),
    billed_hours NUMERIC(10, 2),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Creazione tabella lessons
CREATE TABLE IF NOT EXISTS public.lessons (
    -- Usiamo TEXT come primary key perché l'UID nel JSON a volte è un UUID, a volte è una stringa descrittiva
    id TEXT PRIMARY KEY,
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    start_date_time TIMESTAMP WITH TIME ZONE NOT NULL,
    duration TEXT NOT NULL, -- formato 'HH:MM:SS'
    is_confirmed BOOLEAN DEFAULT false,
    summary TEXT,
    description TEXT,
    location TEXT,
    is_billed BOOLEAN DEFAULT false,
    invoice_number TEXT,
    invoice_date TIMESTAMP WITH TIME ZONE,
    amount NUMERIC(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Abilitazione Row Level Security (RLS)
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

-- Policy single-user per sviluppo
CREATE POLICY "Allow anonymous read/write on contracts" ON public.contracts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow anonymous read/write on lessons" ON public.lessons FOR ALL USING (true) WITH CHECK (true);

-- Trigger per ricalcolare automaticamente billed_hours nei contratti
-- quando una lezione viene inserita, modificata (es. fatturata/sfatturata) o eliminata.
CREATE OR REPLACE FUNCTION public.update_contract_billed_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_contract_id UUID;
BEGIN
    -- Determiniamo quale contract_id aggiornare
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        v_contract_id := NEW.contract_id;
    ELSE
        v_contract_id := OLD.contract_id;
    END IF;

    -- Ricalcoliamo billed_hours per il contratto corrente
    UPDATE public.contracts
    SET billed_hours = (
        SELECT COALESCE(SUM(
            (split_part(duration, ':', 1)::NUMERIC) + 
            (split_part(duration, ':', 2)::NUMERIC / 60.0) +
            (COALESCE(nullif(split_part(duration, ':', 3), ''), '0')::NUMERIC / 3600.0)
        ), 0.0)
        FROM public.lessons
        WHERE contract_id = v_contract_id AND is_billed = true
    )
    WHERE id = v_contract_id;

    -- Se si tratta di un UPDATE e il contract_id è cambiato, aggiorniamo anche il vecchio contratto
    IF (TG_OP = 'UPDATE' AND OLD.contract_id IS DISTINCT FROM NEW.contract_id) THEN
        UPDATE public.contracts
        SET billed_hours = (
            SELECT COALESCE(SUM(
                (split_part(duration, ':', 1)::NUMERIC) + 
                (split_part(duration, ':', 2)::NUMERIC / 60.0) +
                (COALESCE(nullif(split_part(duration, ':', 3), ''), '0')::NUMERIC / 3600.0)
            ), 0.0)
            FROM public.lessons
            WHERE contract_id = OLD.contract_id AND is_billed = true
        )
        WHERE id = OLD.contract_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Creazione trigger
CREATE OR REPLACE TRIGGER trigger_update_contract_billed_hours
AFTER INSERT OR UPDATE OR DELETE ON public.lessons
FOR EACH ROW EXECUTE FUNCTION public.update_contract_billed_hours();
