-- =====================================================================
-- ¡Por Fin! · Esquema de base de datos v1.0 (Supabase / PostgreSQL)
-- Pégalo entero en Supabase → SQL Editor → New query → Run.
-- Se puede ejecutar más de una vez sin romper nada.
--
-- Diseño de seguridad:
--  · Las tablas NO son accesibles directamente desde la app (RLS activado
--    y sin políticas). Todo pasa por las funciones de abajo, que comprueban
--    quién eres, a qué casa perteneces y si eres administrador.
--  · La hora de cada anotación y de cada voto la pone el servidor.
--  · Los puntos y quién valida los calcula el servidor, no el móvil.
-- =====================================================================

-- ---------- Tablas ----------
create table if not exists public.casas (
  id      uuid primary key default gen_random_uuid(),
  nombre  text not null check (char_length(nombre) between 1 and 60),
  params  jsonb not null default '{"pC":1,"pT":1,"pM":1,"mult":2,"bonus":1,"sancion":3,"plazoH":24,"quorum":0.6666666667}',
  creado  timestamptz not null default now()
);

create table if not exists public.miembros (
  id       uuid primary key default gen_random_uuid(),
  casa_id  uuid not null references public.casas(id) on delete cascade,
  email    text not null,
  user_id  uuid references auth.users(id) on delete set null,
  nombre   text not null check (char_length(nombre) between 1 and 40),
  admin    boolean not null default false,
  activo   boolean not null default true,
  creado   timestamptz not null default now(),
  unique (casa_id, email)
);

create table if not exists public.tareas (
  id       uuid primary key default gen_random_uuid(),
  casa_id  uuid not null references public.casas(id) on delete cascade,
  cat      text not null default 'Otras',
  nombre   text not null check (char_length(nombre) between 1 and 80),
  c        smallint not null check (c between 1 and 3),
  t        smallint not null check (t between 1 and 3),
  m        smallint not null check (m between 1 and 3),
  ajuste   numeric check (ajuste is null or ajuste >= 0),
  activa   boolean not null default true,
  borrado  boolean not null default false,
  creado   timestamptz not null default now()
);

create table if not exists public.periodos (
  id       uuid primary key default gen_random_uuid(),
  casa_id  uuid not null references public.casas(id) on delete cascade,
  inicio   timestamptz not null,
  fin      timestamptz not null,
  premio   text not null default '',
  cerrado  boolean not null default false,
  creado   timestamptz not null default now(),
  check (fin > inicio)
);

create table if not exists public.registros (
  id             uuid primary key default gen_random_uuid(),
  casa_id        uuid not null references public.casas(id) on delete cascade,
  periodo_id     uuid not null references public.periodos(id) on delete cascade,
  tarea_id       uuid references public.tareas(id) on delete set null,
  nombre         text not null,
  cat            text not null,
  puntos         numeric not null,
  autor          uuid not null references public.miembros(id),
  participantes  uuid[] not null,
  validadores    uuid[] not null,
  plazo_h        numeric not null,
  quorum         numeric not null,
  fecha          timestamptz not null default now(),
  borrado        boolean not null default false
);

create table if not exists public.votos (
  registro_id  uuid not null references public.registros(id) on delete cascade,
  miembro_id   uuid not null references public.miembros(id) on delete cascade,
  tipo         text not null check (tipo in ('ok','no')),
  motivo       text,
  fecha        timestamptz not null default now(),
  primary key (registro_id, miembro_id),
  check (tipo = 'ok' or motivo is not null)
);

create index if not exists miembros_user_idx   on public.miembros(user_id);
create index if not exists miembros_email_idx  on public.miembros(lower(email));
create index if not exists tareas_casa_idx     on public.tareas(casa_id);
create index if not exists periodos_casa_idx   on public.periodos(casa_id);
create index if not exists registros_per_idx   on public.registros(periodo_id);
create index if not exists registros_casa_idx  on public.registros(casa_id);

alter table public.casas     enable row level security;
alter table public.miembros  enable row level security;
alter table public.tareas    enable row level security;
alter table public.periodos  enable row level security;
alter table public.registros enable row level security;
alter table public.votos     enable row level security;

-- ---------- Funciones auxiliares (internas) ----------

-- Devuelve tu ficha de miembro en una casa, o da error si no perteneces.
create or replace function public._miembro(p_casa uuid, p_admin boolean default false)
returns public.miembros language plpgsql stable security definer set search_path = public as $$
declare v public.miembros;
begin
  if auth.uid() is null then
    raise exception 'Tienes que entrar con tu email.' using errcode = '42501';
  end if;
  select * into v from miembros where casa_id = p_casa and user_id = auth.uid() and activo;
  if v.id is null then
    raise exception 'No perteneces a esta casa.' using errcode = '42501';
  end if;
  if p_admin and not v.admin then
    raise exception 'Solo el administrador puede hacer este cambio.' using errcode = '42501';
  end if;
  return v;
end $$;

-- Quién participa: el autor más los compañeros elegidos que sean miembros activos.
create or replace function public._participantes(p_casa uuid, p_autor uuid, p_con uuid[])
returns uuid[] language sql stable security definer set search_path = public as $$
  select array[p_autor] || coalesce((
    select array_agg(id order by creado) from miembros
    where casa_id = p_casa and activo and id = any(coalesce(p_con, '{}')) and id <> p_autor
  ), '{}');
$$;

-- Quién valida: miembros activos que ya han entrado en la app y no participan.
create or replace function public._validadores(p_casa uuid, p_parts uuid[])
returns uuid[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(id order by creado), '{}') from miembros
  where casa_id = p_casa and activo and user_id is not null and not (id = any(p_parts));
$$;

create or replace function public._vence(r public.registros)
returns timestamptz language sql immutable as $$
  select r.fecha + make_interval(secs => (r.plazo_h * 3600)::double precision);
$$;

-- ---------- Funciones que usa la app ----------

create or replace function public.ahora()
returns timestamptz language sql stable as $$ select now(); $$;

-- Al entrar: te vincula con las casas donde el administrador añadió tu email.
create or replace function public.unirme()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if auth.uid() is null then
    raise exception 'Tienes que entrar con tu email.' using errcode = '42501';
  end if;
  update miembros set user_id = auth.uid()
   where lower(email) = v_email and user_id is null and v_email <> '';
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'nombre', c.nombre, 'admin', m.admin) order by c.creado)
      from miembros m join casas c on c.id = m.casa_id
     where m.user_id = auth.uid() and m.activo
  ), '[]'::jsonb);
end $$;

create or replace function public.crear_casa(
  p_nombre text, p_mi_nombre text, p_premio text,
  p_inicio timestamptz, p_fin timestamptz, p_tareas jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_casa uuid; v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if auth.uid() is null or v_email = '' then
    raise exception 'Tienes que entrar con tu email.' using errcode = '42501';
  end if;
  if (select count(*) from miembros where user_id = auth.uid() and admin) >= 3 then
    raise exception 'Ya administras 3 casas, que es el máximo.';
  end if;
  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_mi_nombre), '') = '' then
    raise exception 'Escribe el nombre de la casa y tu nombre.';
  end if;
  insert into casas(nombre) values (left(trim(p_nombre), 60)) returning id into v_casa;
  insert into miembros(casa_id, email, user_id, nombre, admin)
    values (v_casa, v_email, auth.uid(), left(trim(p_mi_nombre), 40), true);
  insert into tareas(casa_id, cat, nombre, c, t, m, ajuste)
    select v_casa, coalesce(nullif(trim(x ->> 'cat'), ''), 'Otras'), left(trim(x ->> 'nombre'), 80),
           least(3, greatest(1, coalesce((x ->> 'c')::int, 1))),
           least(3, greatest(1, coalesce((x ->> 't')::int, 1))),
           least(3, greatest(1, coalesce((x ->> 'm')::int, 1))),
           nullif(x ->> 'ajuste', '')::numeric
      from jsonb_array_elements(coalesce(p_tareas, '[]'::jsonb)) x
     where coalesce(trim(x ->> 'nombre'), '') <> '';
  insert into periodos(casa_id, inicio, fin, premio)
    values (v_casa, p_inicio, p_fin, coalesce(left(p_premio, 120), ''));
  return v_casa;
end $$;

-- Todo lo que necesita la pantalla, en una sola llamada.
create or replace function public.estado_casa(p_casa uuid, p_extra uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_yo public.miembros := public._miembro(p_casa);
begin
  return jsonb_build_object(
    'servidor', now(),
    'yo', v_yo.id,
    'casa', (select jsonb_build_object('id', id, 'nombre', nombre, 'params', params) from casas where id = p_casa),
    'miembros', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'nombre', nombre, 'admin', admin, 'activo', activo, 'unido', user_id is not null,
        'email', case when v_yo.admin or id = v_yo.id then email end) order by creado)
      from miembros where casa_id = p_casa), '[]'::jsonb),
    'tareas', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'cat', cat, 'nombre', nombre, 'c', c, 't', t, 'm', m, 'ajuste', ajuste, 'activa', activa) order by creado)
      from tareas where casa_id = p_casa and not borrado), '[]'::jsonb),
    'periodos', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'inicio', inicio, 'fin', fin, 'premio', premio, 'cerrado', cerrado) order by inicio)
      from periodos where casa_id = p_casa), '[]'::jsonb),
    'registros', coalesce((select jsonb_agg(jsonb_build_object(
        'id', r.id, 'tareaId', r.tarea_id, 'nombre', r.nombre, 'cat', r.cat, 'puntos', r.puntos,
        'autor', r.autor, 'participantes', r.participantes, 'validadores', r.validadores,
        'plazoH', r.plazo_h, 'quorum', r.quorum, 'fecha', r.fecha, 'periodoId', r.periodo_id,
        'votos', coalesce((select jsonb_object_agg(v.miembro_id::text, jsonb_build_object(
                    'tipo', v.tipo, 'motivo', v.motivo, 'fecha', v.fecha))
                  from votos v where v.registro_id = r.id), '{}'::jsonb)) order by r.fecha)
      from registros r join periodos p on p.id = r.periodo_id
     where r.casa_id = p_casa and not r.borrado and (not p.cerrado or r.periodo_id = p_extra)), '[]'::jsonb)
  );
end $$;

create or replace function public.anotar(p_casa uuid, p_tarea uuid, p_con uuid[] default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_yo public.miembros := public._miembro(p_casa);
  v_t public.tareas; v_p public.periodos; v_par jsonb;
  v_parts uuid[]; v_vals uuid[]; v_pts numeric; v_id uuid;
begin
  select * into v_p from periodos
   where casa_id = p_casa and not cerrado and now() between inicio and fin
   order by inicio desc limit 1;
  if v_p.id is null then
    raise exception 'No hay ningún periodo en marcha ahora mismo. El administrador puede crearlo en Ajustes.';
  end if;
  select * into v_t from tareas where id = p_tarea and casa_id = p_casa and activa and not borrado;
  if v_t.id is null then
    raise exception 'Esa tarea ya no está en el catálogo.';
  end if;
  select params into v_par from casas where id = p_casa;
  v_parts := public._participantes(p_casa, v_yo.id, p_con);
  v_vals  := public._validadores(p_casa, v_parts);
  if cardinality(v_vals) = 0 then
    raise exception 'Tiene que quedar al menos una persona que ya haya entrado en la app para validar la tarea.';
  end if;
  v_pts := coalesce(round(v_t.ajuste),
           round((v_t.c * (v_par->>'pC')::numeric + v_t.t * (v_par->>'pT')::numeric
                + v_t.m * (v_par->>'pM')::numeric) * (v_par->>'mult')::numeric));
  insert into registros(casa_id, periodo_id, tarea_id, nombre, cat, puntos, autor,
                        participantes, validadores, plazo_h, quorum)
  values (p_casa, v_p.id, v_t.id, v_t.nombre, v_t.cat, v_pts, v_yo.id,
          v_parts, v_vals, (v_par->>'plazoH')::numeric, (v_par->>'quorum')::numeric)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.compartir(p_registro uuid, p_con uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare r public.registros; v_yo public.miembros; v_parts uuid[]; v_vals uuid[];
begin
  select * into r from registros where id = p_registro and not borrado;
  if r.id is null then raise exception 'Esa tarea ya no existe.'; end if;
  v_yo := public._miembro(r.casa_id);
  if r.autor <> v_yo.id then
    raise exception 'Solo quien anotó la tarea puede cambiar con quién la hizo.';
  end if;
  if exists (select 1 from votos where registro_id = r.id) then
    raise exception 'Ya hay votos en esta tarea. Anúlala y vuelve a anotarla si quieres cambiar quién la hizo.';
  end if;
  if now() >= public._vence(r) then raise exception 'El plazo de esta tarea ya ha terminado.'; end if;
  v_parts := public._participantes(r.casa_id, v_yo.id, p_con);
  v_vals  := public._validadores(r.casa_id, v_parts);
  if cardinality(v_vals) = 0 then
    raise exception 'Tiene que quedar al menos una persona que ya haya entrado en la app para validar la tarea.';
  end if;
  update registros set participantes = v_parts, validadores = v_vals where id = r.id;
end $$;

create or replace function public.anular(p_registro uuid, p_anular boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare r public.registros; v_yo public.miembros;
begin
  select * into r from registros where id = p_registro;
  if r.id is null then raise exception 'Esa tarea ya no existe.'; end if;
  v_yo := public._miembro(r.casa_id);
  if r.autor <> v_yo.id then raise exception 'Solo quien anotó la tarea puede anularla.'; end if;
  if p_anular and exists (select 1 from votos where registro_id = r.id) then
    raise exception 'Ya hay votos en esta tarea, así que no se puede anular.';
  end if;
  update registros set borrado = p_anular where id = r.id;
end $$;

create or replace function public.votar(p_registro uuid, p_tipo text, p_motivo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r public.registros; v_yo public.miembros;
begin
  select * into r from registros where id = p_registro and not borrado;
  if r.id is null then raise exception 'Esa tarea ya no existe: quien la anotó la ha anulado.'; end if;
  v_yo := public._miembro(r.casa_id);
  if not (v_yo.id = any(r.validadores)) then raise exception 'No te toca validar esta tarea.'; end if;
  if now() >= public._vence(r) then raise exception 'El plazo para responder ya ha terminado.'; end if;
  if p_tipo not in ('ok', 'no') then raise exception 'Respuesta no válida.'; end if;
  if p_tipo = 'no' and coalesce(trim(p_motivo), '') = '' then
    raise exception 'Elige un motivo para poder rechazarla.';
  end if;
  insert into votos(registro_id, miembro_id, tipo, motivo)
  values (r.id, v_yo.id, p_tipo, case when p_tipo = 'no' then left(trim(p_motivo), 60) end)
  on conflict (registro_id, miembro_id)
  do update set tipo = excluded.tipo, motivo = excluded.motivo, fecha = now();
end $$;

create or replace function public.retirar_voto(p_registro uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.registros; v_yo public.miembros;
begin
  select * into r from registros where id = p_registro;
  if r.id is null then raise exception 'Esa tarea ya no existe.'; end if;
  v_yo := public._miembro(r.casa_id);
  if now() >= public._vence(r) then raise exception 'El plazo ya ha terminado; tu respuesta se queda como está.'; end if;
  delete from votos where registro_id = r.id and miembro_id = v_yo.id;
end $$;

-- ---------- Funciones de administración ----------

create or replace function public.guardar_periodo(
  p_casa uuid, p_id uuid, p_inicio timestamptz, p_fin timestamptz, p_premio text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public._miembro(p_casa, true);
  if p_fin <= p_inicio then raise exception 'Revisa las fechas: el final no puede ser anterior al inicio.'; end if;
  if p_id is null then
    insert into periodos(casa_id, inicio, fin, premio)
    values (p_casa, p_inicio, p_fin, coalesce(left(p_premio, 120), '')) returning id into v_id;
  else
    update periodos set inicio = p_inicio, fin = p_fin, premio = coalesce(left(p_premio, 120), '')
     where id = p_id and casa_id = p_casa returning id into v_id;
    if v_id is null then raise exception 'Ese periodo no existe.'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.cerrar_periodo(p_casa uuid, p_id uuid, p_cerrado boolean default true)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._miembro(p_casa, true);
  update periodos set cerrado = p_cerrado where id = p_id and casa_id = p_casa;
end $$;

create or replace function public.guardar_miembro(
  p_casa uuid, p_id uuid default null, p_nombre text default null, p_email text default null,
  p_admin boolean default null, p_activo boolean default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_email text := lower(trim(coalesce(p_email, '')));
begin
  perform public._miembro(p_casa, true);
  if v_email <> '' and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Escribe un email válido.';
  end if;
  begin
    if p_id is null then
      if v_email = '' or coalesce(trim(p_nombre), '') = '' then
        raise exception 'Escribe el nombre y el email del nuevo miembro.';
      end if;
      if exists (select 1 from miembros where casa_id = p_casa and email = v_email and activo) then
        raise exception 'Ese email ya está en la casa.';
      end if;
      update miembros set activo = true, nombre = left(trim(p_nombre), 40)
       where casa_id = p_casa and email = v_email and not activo returning id into v_id;
      if v_id is null then
        insert into miembros(casa_id, email, nombre, admin)
        values (p_casa, v_email, left(trim(p_nombre), 40), coalesce(p_admin, false)) returning id into v_id;
      end if;
    else
      update miembros set
        nombre = coalesce(nullif(left(trim(p_nombre), 40), ''), nombre),
        admin  = coalesce(p_admin, admin),
        activo = coalesce(p_activo, activo),
        email  = case when user_id is null and v_email <> '' then v_email else email end
       where id = p_id and casa_id = p_casa returning id into v_id;
      if v_id is null then raise exception 'Ese miembro no existe.'; end if;
    end if;
  exception when unique_violation then
    raise exception 'Ese email ya está en la casa.';
  end;
  if not exists (select 1 from miembros where casa_id = p_casa and admin and activo) then
    raise exception 'Tiene que haber al menos un administrador.';
  end if;
  return v_id;
end $$;

create or replace function public.guardar_tarea(p_casa uuid, p_id uuid default null, p_datos jsonb default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public._miembro(p_casa, true);
  if p_id is null then
    if coalesce(trim(p_datos ->> 'nombre'), '') = '' then raise exception 'La tarea necesita un nombre.'; end if;
    insert into tareas(casa_id, cat, nombre, c, t, m, ajuste, activa)
    values (p_casa, coalesce(nullif(trim(p_datos ->> 'cat'), ''), 'Otras'), left(trim(p_datos ->> 'nombre'), 80),
            coalesce((p_datos ->> 'c')::smallint, 1), coalesce((p_datos ->> 't')::smallint, 1),
            coalesce((p_datos ->> 'm')::smallint, 1), nullif(p_datos ->> 'ajuste', '')::numeric,
            coalesce((p_datos ->> 'activa')::boolean, true))
    returning id into v_id;
  else
    update tareas set
      cat     = coalesce(nullif(trim(p_datos ->> 'cat'), ''), cat),
      nombre  = coalesce(nullif(left(trim(p_datos ->> 'nombre'), 80), ''), nombre),
      c       = coalesce((p_datos ->> 'c')::smallint, c),
      t       = coalesce((p_datos ->> 't')::smallint, t),
      m       = coalesce((p_datos ->> 'm')::smallint, m),
      ajuste  = case when p_datos ? 'ajuste' then nullif(p_datos ->> 'ajuste', '')::numeric else ajuste end,
      activa  = coalesce((p_datos ->> 'activa')::boolean, activa),
      borrado = coalesce((p_datos ->> 'borrado')::boolean, borrado)
     where id = p_id and casa_id = p_casa returning id into v_id;
    if v_id is null then raise exception 'Esa tarea no existe.'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.importar_tareas(p_casa uuid, p_lista jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare x jsonb; v_id uuid; n_new int := 0; n_upd int := 0;
begin
  perform public._miembro(p_casa, true);
  for x in select * from jsonb_array_elements(coalesce(p_lista, '[]'::jsonb)) loop
    continue when coalesce(trim(x ->> 'nombre'), '') = '';
    select id into v_id from tareas
     where casa_id = p_casa and not borrado and lower(nombre) = lower(trim(x ->> 'nombre')) limit 1;
    if v_id is null then
      insert into tareas(casa_id, cat, nombre, c, t, m, ajuste, activa)
      values (p_casa, coalesce(nullif(trim(x ->> 'cat'), ''), 'Otras'), left(trim(x ->> 'nombre'), 80),
              least(3, greatest(1, coalesce((x ->> 'c')::int, 1))),
              least(3, greatest(1, coalesce((x ->> 't')::int, 1))),
              least(3, greatest(1, coalesce((x ->> 'm')::int, 1))),
              nullif(x ->> 'ajuste', '')::numeric, coalesce((x ->> 'activa')::boolean, true));
      n_new := n_new + 1;
    else
      update tareas set
        cat = coalesce(nullif(trim(x ->> 'cat'), ''), cat),
        c = least(3, greatest(1, coalesce((x ->> 'c')::int, c))),
        t = least(3, greatest(1, coalesce((x ->> 't')::int, t))),
        m = least(3, greatest(1, coalesce((x ->> 'm')::int, m))),
        ajuste = nullif(x ->> 'ajuste', '')::numeric,
        activa = coalesce((x ->> 'activa')::boolean, activa)
       where id = v_id;
      n_upd := n_upd + 1;
    end if;
  end loop;
  return jsonb_build_object('nuevas', n_new, 'actualizadas', n_upd);
end $$;

create or replace function public.guardar_reglas(p_casa uuid, p_params jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare k text; v numeric; limpio jsonb := '{}'::jsonb;
begin
  perform public._miembro(p_casa, true);
  foreach k in array array['pC','pT','pM','mult','bonus','sancion','plazoH','quorum'] loop
    if p_params ? k then
      v := (p_params ->> k)::numeric;
      if v is null or v < 0 then raise exception 'Revisa los números: no pueden estar vacíos ni ser negativos.'; end if;
      if k = 'plazoH' and v < 1 then v := 1; end if;
      if k = 'quorum' and (v <= 0 or v > 1) then raise exception 'Las validaciones necesarias no son válidas.'; end if;
      limpio := limpio || jsonb_build_object(k, v);
    end if;
  end loop;
  update casas set params = params || limpio where id = p_casa;
end $$;

-- ---------- Permisos ----------
-- Nadie accede a las tablas directamente; solo a estas funciones, y solo con sesión iniciada.
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.ahora(), public.unirme(),
  public.crear_casa(text, text, text, timestamptz, timestamptz, jsonb),
  public.estado_casa(uuid, uuid),
  public.anotar(uuid, uuid, uuid[]), public.compartir(uuid, uuid[]),
  public.anular(uuid, boolean), public.votar(uuid, text, text), public.retirar_voto(uuid),
  public.guardar_periodo(uuid, uuid, timestamptz, timestamptz, text),
  public.cerrar_periodo(uuid, uuid, boolean),
  public.guardar_miembro(uuid, uuid, text, text, boolean, boolean),
  public.guardar_tarea(uuid, uuid, jsonb), public.importar_tareas(uuid, jsonb),
  public.guardar_reglas(uuid, jsonb)
to authenticated;
