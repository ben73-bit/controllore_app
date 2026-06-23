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
