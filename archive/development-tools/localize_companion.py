from pathlib import Path
import json
rows = '''Actividad|Activity|Activitat
Tu equipo en marcha.|Your team, at work.|El teu equip en marxa.
Cada agente conserva su conversación y su trabajo.|Each agent keeps its own conversation and work.|Cada agent conserva la seva conversa i la seva feina.
Trabajos simultáneos|Concurrent tasks|Tasques simultànies
En curso|In progress|En curs
El equipo está listo. Puedes hablar con varios agentes a la vez.|Your team is ready. You can talk to several agents at once.|L'equip està preparat. Pots parlar amb diversos agents alhora.
Rutinas|Routines|Rutines
Nueva rutina|New routine|Nova rutina
Se ejecutan con Aster abierto y el Mac despierto. Respetan el límite diario y las horas de descanso de Conexiones. Los resultados llegan a la bandeja.|Runs while Aster is open and your Mac is awake. Uses the daily limit and quiet hours in Connections. Results appear in your inbox.|S'executen amb Aster obert i el Mac despert. Respecten el límit diari i les hores de descans de Connexions. Els resultats arriben a la safata.
Preparar mi día|Prepare my day|Preparar el meu dia
Avanzar mi empresa|Move my company forward|Fer avançar la meva empresa
Activa|Active|Activa
En pausa|Paused|En pausa
Editar|Edit|Editar
Activar|Enable|Activar
Ejecutar ahora|Run now|Executar ara
Próxima ejecución|Next run|Propera execució
Historial|History|Historial
Necesitan atención|Needs attention|Necessiten atenció
Abrir|Open|Obrir
Tu rutina|Your routine|La teva rutina
Espacio|Workspace|Espai
Qué debe hacer y cómo comprobar el resultado|What to do and how to check the result|Què ha de fer i com comprovar el resultat
Frecuencia|Frequency|Freqüència
Cada día|Every day|Cada dia
De lunes a viernes|Weekdays|De dilluns a divendres
Minuto|Minute|Minut
Zona horaria|Time zone|Zona horària
Activar al guardar|Enable when saved|Activar en desar
Si el Mac estaba apagado, Aster hará una sola ejecución al volver. Si una ejecución necesita revisión, la rutina se pausa para no repetir acciones.|If your Mac was off, Aster catches up once when it returns. A run that needs review pauses the routine to avoid repeating actions.|Si el Mac estava apagat, Aster farà una sola execució en tornar. Si una execució necessita revisió, la rutina es pausa per no repetir accions.
Guardar rutina|Save routine|Desar rutina
A tu lado|By your side|Al teu costat
A tu lado · ⌥⌘K|By your side · ⌥⌘K|Al teu costat · ⌥⌘K
Abrir A tu lado|Open By your side|Obrir Al teu costat
Un compañero junto al cursor. Explicaciones, dibujos y tareas sobre tu pantalla.|A companion beside your cursor. Explanations, drawings, and tasks on your screen.|Un company al costat del cursor. Explicacions, dibuixos i tasques sobre la pantalla.
Seguir cursor|Follow cursor|Seguir el cursor
Cerrar A tu lado|Close By your side|Tancar Al teu costat
¿Lo vemos juntos?|Let's look together.|Ho mirem junts?
Pregunta sobre lo que tienes delante. Puedo explicarlo, señalarlo o dibujar contigo.|Ask about what's in front of you. I can explain it, point it out, or draw with you.|Pregunta sobre el que tens davant. Puc explicar-ho, assenyalar-ho o dibuixar amb tu.
Explicar envía una captura a OpenAI. La pantalla no se observa continuamente.|Explain sends one screenshot to OpenAI. Your screen is not watched continuously.|Explicar envia una captura a OpenAI. La pantalla no s'observa contínuament.
Mirando y preparando la explicación…|Looking and preparing an explanation…|Mirant i preparant l'explicació…
Dibujar|Draw|Dibuixar
Borrar marcas|Clear marks|Esborrar marques
Leer la explicación en voz alta|Read the explanation aloud|Llegir l'explicació en veu alta
Pregúntame o encárgame algo…|Ask me or give me a task…|Pregunta'm o encarrega'm alguna cosa…
Pregunta para A tu lado|Question for By your side|Pregunta per a Al teu costat
Explicar|Explain|Explicar
Hacer la tarea|Do the task|Fer la tasca
Escape cierra las marcas o el panel. Durante una tarea, detiene el control.|Escape clears marks or closes the panel. During a task, it stops control.|Escape tanca les marques o el panell. Durant una tasca, atura el control.
Listo · Esc|Done · Esc|Fet · Esc
line|Freehand|Traç lliure
arrow|Arrow|Fletxa
circle|Circle|Cercle
rectangle|Rectangle|Rectangle
Pausa la tarea del Mac antes de abrir A tu lado.|Pause the Mac task before opening By your side.|Pausa la tasca del Mac abans d'obrir Al teu costat.
Activa el permiso de Pantalla en Ordenador para usar A tu lado.|Enable Screen access in Computer to use By your side.|Activa el permís de Pantalla a Ordinador per fer servir Al teu costat.
Activa Pantalla y Accesibilidad en Ordenador para trabajar en tus apps.|Enable Screen and Accessibility in Computer to work in your apps.|Activa Pantalla i Accessibilitat a Ordinador per treballar amb les teves apps.
La app ha cambiado. Vuelve a preguntar para colocar las marcas sobre la pantalla actual.|The app changed. Ask again to place marks on the current screen.|L'app ha canviat. Torna a preguntar per situar les marques a la pantalla actual.
No se pudo registrar ⌥⌘K. Abre A tu lado desde el menú de Aster.|Could not register ⌥⌘K. Open By your side from Aster's menu.|No s'ha pogut registrar ⌥⌘K. Obre Al teu costat des del menú d'Aster.
Consulta mi calendario y recordatorios conectados. Propón tres prioridades realistas para hoy, señala conflictos y di qué información falta. No cambies mis citas.|Check my connected calendar and reminders. Suggest three realistic priorities for today, identify conflicts, and state what information is missing. Do not change my events.|Consulta el meu calendari i recordatoris connectats. Proposa tres prioritats realistes per avui, assenyala conflictes i digues quina informació falta. No canviïs les meves cites.
Revisa nuestras tareas y trabajo reciente. Prepara un ejercicio corto de repaso con pistas y una solución explicada aparte. No inventes asignaturas o fechas que no conoces.|Review our tasks and recent work. Prepare a short revision exercise with hints and a separately explained solution. Do not invent subjects or dates you do not know.|Revisa les nostres tasques i la feina recent. Prepara un exercici curt de repàs amb pistes i una solució explicada a part. No inventis assignatures o dates que no coneixes.
Revisa el objetivo, las tareas y el trabajo anterior de esta empresa. Prepara un entregable nuevo y concreto que la haga avanzar. Comprueba tus supuestos y guarda los próximos pasos como tareas locales.|Review this company's goal, tasks, and previous work. Prepare a new, concrete deliverable that moves it forward. Check your assumptions and save next steps as local tasks.|Revisa l'objectiu, les tasques i la feina anterior d'aquesta empresa. Prepara un lliurable nou i concret que la faci avançar. Comprova les hipòtesis i desa els propers passos com a tasques locals.'''
for index, lang in [(1,'en'),(2,'ca')]:
 p=Path('outputs/Aster-macOS/Localization')/f'{lang}.json'; data=json.loads(p.read_text())
 for row in rows.splitlines():
  parts=row.split('|'); assert len(parts)==3; data[parts[0]]=parts[index]
 p.write_text(json.dumps(data,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
print('English and Catalan companion and routine strings added.')
