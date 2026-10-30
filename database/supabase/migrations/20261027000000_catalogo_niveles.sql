-- =============================================================================
--  27 Catálogo de niveles de formación (RF-AC-004, RF-AC-020)
--
--  Los niveles (Pregrado, Especialización, Maestría, Doctorado…) se administran en
--  Catálogos › Niveles: se agregan, editan e inactivan sin tocar la base. Cada nivel es de
--  tipo pregrado o posgrado. Programas académicos elige su nivel de este catálogo (nivel_id);
--  la columna vieja programa_academico.nivel (enum) se mantiene sincronizada por un trigger
--  para la importación desde Excel y queda vacía si el nivel no existe en el enum.
--  Historias académicas lista los niveles que tienen programas activos.
-- =============================================================================

create table if not exists nivel_formacion (
  id              bigint generated always as identity primary key,
  codigo          text not null unique,                     -- se genera del nombre si no viene
  nombre          text not null,
  tipo            text not null default 'posgrado' check (tipo in ('pregrado', 'posgrado')),
  orden           integer not null default 100,
  estado          estado_registro not null default 'activo',
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);
create unique index if not exists nivel_formacion_nombre_unico on nivel_formacion (lower(nombre));
comment on table nivel_formacion is 'RF-AC-004. Niveles de formación de los programas (Pregrado, Especialización, Maestría…). Sin borrado: se inactiva.';

-- Código a partir del nombre ("Especialización" → "especializacion").
create or replace function fn_trg_nivel_formacion_codigo()
returns trigger
language plpgsql
as $$
begin
  new.nombre := trim(regexp_replace(new.nombre, '\s+', ' ', 'g'));
  if new.codigo is null or trim(new.codigo) = '' then
    new.codigo := trim(both '_' from lower(regexp_replace(unaccent(new.nombre), '[^a-zA-Z0-9]+', '_', 'g')));
  end if;
  return new;
end $$;

drop trigger if exists nivel_formacion_codigo on nivel_formacion;
create trigger nivel_formacion_codigo before insert or update of nombre, codigo on nivel_formacion
for each row execute function fn_trg_nivel_formacion_codigo();

drop trigger if exists nivel_formacion_auditar on nivel_formacion;
create trigger nivel_formacion_auditar after insert or update on nivel_formacion
for each row execute function fn_trg_auditar_cambios();

insert into nivel_formacion (codigo, nombre, tipo, orden) values
  ('pregrado', 'Pregrado', 'pregrado', 10),
  ('especializacion', 'Especialización', 'posgrado', 20),
  ('maestria', 'Maestría', 'posgrado', 30),
  ('doctorado', 'Doctorado', 'posgrado', 40),
  ('posgrado', 'Posgrado', 'posgrado', 90)
on conflict (codigo) do nothing;

-- Programas: nivel del catálogo.
alter table programa_academico add column if not exists nivel_id bigint references nivel_formacion(id);
alter table programa_academico alter column nivel drop not null;
update programa_academico p set nivel_id = n.id
  from nivel_formacion n
 where p.nivel_id is null and n.codigo = p.nivel::text;
create unique index if not exists programa_nombre_nivel_id_unico on programa_academico (lower(nombre), nivel_id);

-- nivel_id ⇄ nivel (enum): el que venga completa al otro.
create or replace function fn_trg_programa_nivel()
returns trigger
language plpgsql
as $$
declare
  v_codigo text;
begin
  if new.nivel_id is null and new.nivel is not null then
    select id into new.nivel_id from nivel_formacion where codigo = new.nivel::text;
  end if;
  if new.nivel_id is null then
    raise exception '[campo:nivel_id|tipo:obligatorio] Elija el nivel del programa' using errcode = '22023';
  end if;
  select codigo into v_codigo from nivel_formacion where id = new.nivel_id;
  if v_codigo is null then
    raise exception '[campo:nivel_id|tipo:existente] El nivel no existe' using errcode = '22023';
  end if;
  new.nivel := case when v_codigo in (select e.enumlabel::text from pg_enum e where e.enumtypid = 'nivel_academico'::regtype)
                    then v_codigo::nivel_academico end;
  return new;
end $$;

drop trigger if exists programa_nivel on programa_academico;
create trigger programa_nivel before insert or update of nivel, nivel_id on programa_academico
for each row execute function fn_trg_programa_nivel();

-- El catálogo genérico (fn_catalogo_guardar / fn_catalogo_estado) conoce la tabla nueva.
create or replace function fn_catalogo_permiso(p_tabla text)
returns text
language sql immutable
as $$
  select case p_tabla
    when 'dependencia' then 'catalogos.gestionar'
    when 'trd' then 'catalogos.gestionar'
    when 'asunto' then 'catalogos.gestionar'
    when 'tipo_documental' then 'catalogos.gestionar'
    when 'programa_academico' then 'catalogos.gestionar'
    when 'nivel_formacion' then 'catalogos.gestionar'
    when 'ubicacion_fisica' then 'catalogos.gestionar'
    when 'usuario' then 'usuarios.gestionar'
  end
$$;

create or replace function fn_catalogo_columnas(p_tabla text)
returns text[]
language sql immutable
as $$
  select case p_tabla
    when 'dependencia' then array['codigo', 'nombre', 'dependencia_padre_id', 'responsable', 'correo_oficial', 'nova_dependency_id']
    when 'trd' then array['codigo', 'nombre', 'descripcion', 'serie_padre_id', 'anios_gestion', 'anios_central', 'disposicion_final']
    when 'asunto' then array['dependencia_id', 'nombre', 'trd_id', 'descripcion']
    when 'tipo_documental' then array['nombre']
    when 'programa_academico' then array['codigo', 'nombre', 'nivel', 'nivel_id']
    when 'nivel_formacion' then array['nombre', 'tipo', 'orden']
    when 'ubicacion_fisica' then array['carro', 'estante', 'bandeja', 'descripcion', 'bodega', 'modulo']
    -- Los usuarios llegan de NOVA: aquí solo se asignan perfil y dependencia.
    when 'usuario' then array['dependencia_id', 'perfil']
  end
$$;
