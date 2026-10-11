import json

path = 'flujos n8n/F2_remitir_v3.json'
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for n in data['nodes']:
    if n['name'] == 'Validar estado y dependencia':
        code = n['parameters']['jsCode']
        code = code.replace(
            'return [{ json: { ok: true, ...s, consecutivo: r.consecutivo, asunto: r.asunto, dependencia: r.dependencia, correo_oficial: r.correo_oficial, adjuntos: r.adjuntos || [] } }];',
            'return [{ json: { ok: true, ...s, consecutivo: r.consecutivo, asunto: r.asunto, cuerpo: r.cuerpo, remitente_nombre: r.remitente_nombre, remitente_correo: r.remitente_correo, dependencia: r.dependencia, correo_oficial: r.correo_oficial, adjuntos: r.adjuntos || [] } }];'
        )
        n['parameters']['jsCode'] = code
    if n['name'] == 'Armar correo':
        code = n['parameters']['jsCode']
        remitente_html = """const remitenteHtml = v.remitente_nombre || v.remitente_correo ? `<p><strong>Remitente original:</strong> ${v.remitente_nombre || ''} ${v.remitente_correo ? `(${v.remitente_correo})` : ''}</p>` : '';"""
        cuerpo_html = """const cuerpoHtml = v.cuerpo ? `<p><strong>Contenido:</strong></p><blockquote style="border-left: 3px solid #ccc; margin: 0; padding-left: 10px;">${v.cuerpo.replace(/\\n/g, '<br>')}</blockquote>` : '';"""
        new_html = """const html = `<p>Estimada dependencia <strong>${v.dependencia}</strong>:</p>
<p>En atención a la comunicación <strong>${v.consecutivo}</strong> sobre "${v.asunto}", ${remitir ? 'se remite para su gestión.' : 'se devuelve para complementar la respuesta.'}</p>
${remitenteHtml}
${cuerpoHtml}
${v.mensaje ? `<p><strong>Mensaje del gestor:</strong> ${v.mensaje.replace(/\\n/g, '<br>')}</p>` : ''}
<p>Plazo: ${v.plazo_dias_habiles} días hábiles.</p>
<p>Cordialmente,<br>Archivo Central</p>`;"""
        # Reemplazar solo la línea del html original
        lines = code.split('\n')
        new_lines = []
        skip = False
        for i, line in enumerate(lines):
            if 'const html = ' in line and not skip:
                # Encontramos el inicio del html original, reemplazamos hasta el return
                new_lines.append(remitente_html)
                new_lines.append(cuerpo_html)
                new_lines.append(new_html)
                skip = True
                continue
            if skip:
                if line.strip().startswith('return '):
                    new_lines.append(line)
                    skip = False
                continue
            new_lines.append(line)
        n['parameters']['jsCode'] = '\n'.join(new_lines)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print('Actualizado')
