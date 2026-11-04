-- =============================================================================
--  Datos de DEMOSTRACIÓN (solo desarrollo). Tomados de los mockups.
--  Todos los nombres y correos son ficticios. NO cargar en producción:
--  la TRD, asuntos y correos oficiales reales los entrega el cliente.
-- =============================================================================

insert into dependencia (codigo, nombre, responsable, correo_oficial) values
  ('100', 'Rectoría',                 'María E. Velasco', 'rectoria@uniautonoma.edu.co'),
  ('110', 'Secretaría General',       'Carolina Muñoz',   'secretaria.general@uniautonoma.edu.co'),
  ('120', 'Mercadeo',                 'Juliana Rengifo',  'mercadeo@uniautonoma.edu.co'),
  ('130', 'Dirección Administrativa', 'Hernán Velasco',   'direccion.administrativa@uniautonoma.edu.co'),
  ('140', 'Gestión Documental',       'Diana Paz',        'gestion.documental@uniautonoma.edu.co'),
  ('150', 'Registro Académico',       'Jorge Imbachí',    'registro.academico@uniautonoma.edu.co'),
  ('160', 'Talento Humano',           'Sandra Muñoz',     'talento.humano@uniautonoma.edu.co'),
  ('170', 'Financiera',               'Luis E. Caicedo',  'financiera@uniautonoma.edu.co'),
  ('180', 'Bienestar Universitario',  null,               'bienestar.universitario@uniautonoma.edu.co')
on conflict (codigo) do nothing;

update dependencia h set dependencia_padre_id = p.id
from dependencia p
where p.codigo = case when h.codigo = '150' then '110' else '100' end
  and h.codigo <> '100' and h.dependencia_padre_id is null;

-- TRD de ejemplo: código = dependencia + serie.
insert into trd (codigo, nombre, descripcion, anios_gestion, anios_central, disposicion_final) values
  ('100.01', 'Resoluciones',            'Resoluciones rectorales',                         2, 8,  'conservacion_total'),
  ('100.02', 'Comunicaciones',          'Comunicaciones oficiales de Rectoría',            2, 5,  'seleccion'),
  ('100.03', 'Informes de gestión',     'Informes a Consejo Superior y entes de control',  2, 8,  'conservacion_total'),
  ('110.01', 'Resoluciones',            'Resoluciones de Secretaría General',              2, 8,  'conservacion_total'),
  ('110.02', 'Circulares',              'Circulares institucionales',                      2, 5,  'seleccion'),
  ('110.03', 'Convenios',               'Convenios interinstitucionales y otrosíes',       2, 10, 'conservacion_total'),
  ('110.04', 'Actas',                   'Actas de Consejo Académico y Superior',           2, 10, 'conservacion_total'),
  ('120.02', 'Comunicaciones',          'Comunicaciones de Mercadeo',                      2, 3,  'eliminacion'),
  ('120.03', 'Contratos',               'Contratos de prestación de servicios',            2, 10, 'seleccion'),
  ('140.01', 'Inventarios documentales','Inventarios y control de préstamos',              2, 5,  'conservacion_total'),
  ('140.02', 'Comunicaciones',          'Comunicaciones de Gestión Documental',            2, 3,  'eliminacion'),
  ('150.01', 'Certificados',            'Constancias de estudio y certificados de notas',  2, 5,  'seleccion'),
  ('150.02', 'Comunicaciones',          'Comunicaciones de Registro Académico',            2, 3,  'eliminacion'),
  ('160.01', 'Nómina',                  'Soportes de nómina mensual',                      2, 20, 'conservacion_total'),
  ('170.03', 'Presupuesto',             'Ejecución presupuestal',                          2, 10, 'conservacion_total')
on conflict (codigo) do nothing;

insert into asunto (dependencia_id, nombre, trd_id, descripcion)
select d.id, t.nombre, t.id, t.descripcion
from trd t
join dependencia d on d.codigo = split_part(t.codigo, '.', 1)
on conflict do nothing;

insert into programa_academico (codigo, nombre, nivel) values
  ('DER', 'Derecho',                                   'pregrado'),
  ('ADM', 'Administración de Empresas',                'pregrado'),
  ('CON', 'Contaduría Pública',                        'pregrado'),
  ('ENF', 'Enfermería',                                'pregrado'),
  ('COM', 'Comunicación Social',                       'pregrado'),
  ('SIS', 'Ingeniería de Sistemas',                    'pregrado'),
  ('AMB', 'Ingeniería Ambiental',                      'pregrado'),
  ('PSI', 'Psicología',                                'pregrado'),
  ('EGP', 'Especialización en Gerencia de Proyectos',  'posgrado'),
  ('MED', 'Maestría en Educación',                     'posgrado')
on conflict (codigo) do nothing;
