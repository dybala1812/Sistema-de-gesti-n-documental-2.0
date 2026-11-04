-- =============================================================================
--  Carga / actualización del catálogo de dependencias (RF-AC-001).
--  Idempotente: se puede ejecutar varias veces; actualiza por código.
--  Reemplazar la lista con las dependencias y correos OFICIALES que entregue el cliente.
--  Uso: pegar en el SQL Editor de Supabase o: psql -f database/supabase/datos/dependencias.sql
-- =============================================================================
begin;

with datos(codigo, nombre, codigo_padre, responsable, correo_oficial) as (
  values
  -- codigo  nombre                       padre   responsable         correo oficial
  ('100', 'Rectoría',                     null,   'María E. Velasco', 'rectoria@uniautonoma.edu.co'),
  ('110', 'Secretaría General',           '100',  'Carolina Muñoz',   'secretaria.general@uniautonoma.edu.co'),
  ('120', 'Mercadeo',                     '100',  'Juliana Rengifo',  'mercadeo@uniautonoma.edu.co'),
  ('130', 'Dirección Administrativa',     '100',  'Hernán Velasco',   'direccion.administrativa@uniautonoma.edu.co'),
  ('140', 'Gestión Documental',           '100',  'Diana Paz',        'gestion.documental@uniautonoma.edu.co'),
  ('150', 'Registro Académico',           '110',  'Jorge Imbachí',    'registro.academico@uniautonoma.edu.co'),
  ('160', 'Talento Humano',               '100',  'Sandra Muñoz',     'talento.humano@uniautonoma.edu.co'),
  ('170', 'Financiera',                   '100',  'Luis E. Caicedo',  'financiera@uniautonoma.edu.co'),
  ('180', 'Bienestar Universitario',      '100',  null,               'bienestar.universitario@uniautonoma.edu.co')
),
-- 1) Insertar o actualizar (sin padre todavía, por si el padre viene después en la lista)
upsert as (
  insert into dependencia (codigo, nombre, responsable, correo_oficial, estado)
  select codigo, nombre, responsable, lower(trim(correo_oficial)), 'activo' from datos
  on conflict (codigo) do update
     set nombre         = excluded.nombre,
         responsable    = excluded.responsable,
         correo_oficial = excluded.correo_oficial,
         estado         = 'activo'
  returning id, codigo
)
select count(*) as dependencias_cargadas from upsert;

-- 2) Asignar la dependencia superior por código
with datos(codigo, codigo_padre) as (
  values ('110','100'), ('120','100'), ('130','100'), ('140','100'),
         ('150','110'), ('160','100'), ('170','100'), ('180','100')
)
update dependencia h
   set dependencia_padre_id = p.id
  from datos d
  join dependencia p on p.codigo = d.codigo_padre
 where h.codigo = d.codigo
   and h.dependencia_padre_id is distinct from p.id;

-- Verificación
select d.codigo, d.nombre, p.nombre as depende_de, d.correo_oficial, d.estado
from dependencia d left join dependencia p on p.id = d.dependencia_padre_id
order by d.codigo;

commit;

-- Notas:
--  · No se borra ninguna dependencia (RN-AC-12). Para retirar una: update dependencia set estado = 'inactivo' where codigo = 'XXX';
--  · El correo oficial debe ser único: n8n lo usa para reconocer las respuestas de cada dependencia.
--  · nova_dependency_id se llena solo cuando un usuario de NOVA de esa dependencia entra al módulo (por el código).
