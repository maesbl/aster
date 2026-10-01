from pathlib import Path
import re,json
for name in ['Views.swift','Design.swift','Avatar.swift']:
 p=Path('outputs/Aster-macOS/Sources')/name;s=p.read_text()
 # SwiftUI's runtime String labels need explicit translation.
 pat=r'(Text|Button|Label|Picker|Toggle|TextField|DisclosureGroup|accessibilityLabel|help)\(("(?:\\.|[^"\\])*")'
 def wrap(m):
  if '\\(' in m[2]:return m[0]
  return m[1]+'(L('+m[2]+')'
 s=re.sub(pat,wrap,s)
 for value in ['item.0','agent.role','store.agent.role','store.agent.detail','value.rawValue','mood.rawValue','$0.rawValue','tint.rawValue','title','detail','status','store.activity']:
  s=s.replace('Text('+value+')','Text(L('+value+'))')
 s=s.replace('Label(title, systemImage:', 'Label(L(title), systemImage:').replace('.accessibilityLabel(title).help(title)', '.accessibilityLabel(L(title)).help(L(title))')
 s=s.replace('TextField(store.page == "Misiones" && store.mission != nil ? "Continúa esta misión…" : "¿Qué vamos a crear hoy?",','TextField(L(store.page == "Misiones" && store.mission != nil ? "Continúa esta misión…" : "¿Qué vamos a crear hoy?"),')
 s=s.replace('.accessibilityLabel(store.busy ? "Detener misión" : "Enviar misión")','.accessibilityLabel(L(store.busy ? "Detener misión" : "Enviar misión"))')
 s=s.replace('Button(mission.pinned == true ? "Desfijar" : "Fijar")','Button(L(mission.pinned == true ? "Desfijar" : "Fijar"))').replace('Button(mission.archived == true ? "Restaurar" : "Archivar")','Button(L(mission.archived == true ? "Restaurar" : "Archivar"))')
 s=s.replace('"TÚ" : (store.state.specialists', 'L("TÚ") : (store.state.specialists')
 p.write_text(s)
keys=set()
for p in Path('outputs/Aster-macOS/Sources').glob('*.swift'):
 s=p.read_text()
 for pat in [r'\bL\("((?:\\.|[^"\\])*)"',r'\bLF\("((?:\\.|[^"\\])*)"',r'\b(?:title|detail): "((?:\\.|[^"\\])*)"']:
  for m in re.finditer(pat,s):
   if '\\(' not in m[1]:keys.add(m[1])
keys.update(['Personajes','Empresas','Misiones','Bandeja','Conexiones','Tareas','Memoria','Sistema','Claro','Oscuro','En calma','Pensando','Contento','Curioso','Perla','Lila','Menta','Melocotón','Tinta','Dirección','Marketing','Desarrollo','Negocio','Personal','Continúa esta misión…','¿Qué vamos a crear hoy?','Detener misión','Enviar misión','Fijar','Desfijar','Archivar','Restaurar','TÚ','Rápido','Equilibrado','Profundo','Trabajando','Conectado','Clave válida','Conexión pendiente','Sin comprobar','Clave válida · modelo disponible','Conectado a OpenAI','Sin conectar','Permiso pendiente','Permiso denegado','Activado · pendiente de revisión','Lista','Completada','Fallida','Cancelada','Por recuperar','Cancelación pendiente','Preparando la sesión','El agente está trabajando','El equipo está colaborando','Investigando fuentes','Creando y comprobando archivos','Consultando el espacio de trabajo','Recuperando el trabajo guardado','Retomando la misión','Confirmando la cancelación','La memoria se incluye en tus misiones. Los recuerdos de empresa solo se usan en esa empresa.','La memoria está desactivada. Puedes activarla en Ajustes.'])
Path('work/aster-translation-keys.json').write_text(json.dumps(sorted(keys),ensure_ascii=False,indent=2))
print(len(keys),'interface strings collected')
