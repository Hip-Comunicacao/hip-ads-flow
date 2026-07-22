-- HIP ADS FLOW v1.3.3 — OPERAÇÃO INTERNA
-- Execute TODO este arquivo no Supabase SQL Editor antes de publicar o novo deploy.

-- 1. Novos campos operacionais
alter table public.ad_requests add column if not exists request_type text not null default 'Publicar nova campanha';
alter table public.ad_requests add column if not exists affected_item text;
alter table public.ad_requests add column if not exists next_action text not null default 'Aguardando briefing';
alter table public.ad_requests add column if not exists assigned_to_name text;

-- 2. Novos status
alter table public.ad_requests drop constraint if exists ad_requests_status_check;
update public.ad_requests set status='Em andamento' where status='Em publicação';
alter table public.ad_requests add constraint ad_requests_status_check
check (status in ('Pendente','Em andamento','Alteração pendente','Publicada','Finalizada','Cancelada'));

-- 3. Clientes ativos/inativos e duplicidade sem diferença de maiúsculas/minúsculas
alter table public.clients add column if not exists is_active boolean not null default true;
create unique index if not exists clients_name_unique_ci on public.clients (lower(trim(name)));
grant select,insert,update on public.clients to authenticated;
drop policy if exists "admin manage clients" on public.clients;
create policy "admin manage clients" on public.clients for all to authenticated
using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'))
with check (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

-- 4. Solicitações operacionais dentro de uma campanha/plataforma
create table if not exists public.request_operations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.ad_requests(id) on delete cascade,
  operation_type text not null,
  affected_item text,
  requester_name text not null,
  request_note text not null check(length(trim(request_note))>0),
  status text not null default 'Pendente' check(status in ('Pendente','Concluída','Cancelada')),
  completion_note text,
  created_by uuid not null references auth.users(id),
  completed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
alter table public.request_operations enable row level security;
drop policy if exists "authenticated read operations" on public.request_operations;
create policy "authenticated read operations" on public.request_operations for select to authenticated using(true);
drop policy if exists "authenticated create operations" on public.request_operations;
create policy "authenticated create operations" on public.request_operations for insert to authenticated with check(created_by=auth.uid());
drop policy if exists "traffic update operations" on public.request_operations;
create policy "traffic update operations" on public.request_operations for update to authenticated
using (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('admin','traffic_manager')))
with check (exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('admin','traffic_manager')));
grant select,insert,update on public.request_operations to authenticated;

create or replace view public.request_operations_with_people with(security_invoker=true) as
select o.*, creator.full_name as created_by_name, completer.full_name as completed_by_name
from public.request_operations o
left join public.profiles creator on creator.id=o.created_by
left join public.profiles completer on completer.id=o.completed_by;
grant select on public.request_operations_with_people to authenticated;

-- 5. Histórico das operações
create or replace function public.operation_history_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    perform public.log_request_event(new.request_id,new.created_by,'operation_created',
      'Solicitação operacional "'||new.operation_type||'" registrada por '||new.requester_name||'.',
      jsonb_build_object('operation_id',new.id,'affected_item',new.affected_item));
    update public.ad_requests
      set status=case when status='Publicada' then 'Alteração pendente' else status end,
          updated_by=new.created_by, updated_at=now()
      where id=new.request_id;
  elsif old.status is distinct from new.status and new.status='Concluída' then
    perform public.log_request_event(new.request_id,new.completed_by,'operation_completed',
      'Solicitação operacional "'||new.operation_type||'" concluída. '||coalesce(new.completion_note,''),
      jsonb_build_object('operation_id',new.id));
  end if;
  return new;
end $$;
drop trigger if exists trg_operation_history on public.request_operations;
create trigger trg_operation_history after insert or update of status on public.request_operations
for each row execute function public.operation_history_trigger();

-- 6. Finalização automática somente de campanhas que estavam publicadas
create or replace function public.finalize_expired_requests()
returns integer language plpgsql security definer set search_path=public as $$
declare affected integer;
begin
  update public.ad_requests
  set status='Finalizada', updated_at=now()
  where status='Publicada' and end_date is not null and end_date < current_date;
  get diagnostics affected = row_count;
  return affected;
end $$;
grant execute on function public.finalize_expired_requests() to authenticated;

create index if not exists idx_request_operations_request on public.request_operations(request_id,created_at desc);
create index if not exists idx_clients_active on public.clients(is_active,name);
