-- Asegura que .docx (y el resto de formatos de oficina/imagen comunes) estén en la lista blanca.
insert into parametro (clave, valor, tipo, descripcion)
values (
  'formatos_permitidos',
  'pdf,jpg,jpeg,png,doc,docx,xls,xlsx,txt,zip',
  'lista',
  'Extensiones de archivo permitidas para carga en el SGD'
)
on conflict (clave) do update set
  valor = excluded.valor,
  actualizado_en = now();
