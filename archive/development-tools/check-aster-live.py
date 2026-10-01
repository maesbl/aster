import json, pathlib, urllib.request, urllib.error, time
root=pathlib.Path('/Users/mescu/Documents/Codex/2026-09-30/i-w')
key=next(x.split('=',1)[1].strip().strip('\"\'') for x in (root/'.env.local').read_text().splitlines() if x.startswith('OPENAI_API_KEY='))
base='https://api.openai.com/v1'
sid=None; tid=None; report={}; started=time.monotonic()
def req(path, method='GET', data=None):
    r=urllib.request.Request(base+path, data=None if data is None else json.dumps(data).encode(),method=method,headers={'Authorization':'Bearer '+key,'OpenAI-Beta':'agents=v1','Content-Type':'application/json'})
    try:return urllib.request.urlopen(r,timeout=180)
    except urllib.error.HTTPError as e:
        obj=json.loads(e.read()); err=obj.get('error',{})
        raise RuntimeError(str(e.code)+' '+str(err.get('code',''))+' '+str(err.get('message','')).replace(key,'[redacted]'))
def get(path,method='GET',data=None):
    with req(path,method,data) as r:return json.load(r)
try:
    models=get('/models')
    names=sorted(x['id'] for x in models.get('data',[]) if x['id'].startswith(('gpt-6','gpt-5','gpt-4.1')))
    report['available_models']=names
    print(json.dumps({'model_access': names},ensure_ascii=False),flush=True)
    body={'agent':{'model':'gpt-6-astra','instructions':'Responde de forma breve en español. Para esta prueba crea exactamente /workspace/outputs/aster-check.txt con el texto ASTER_OK_2026. Usa una operación real de archivo. No uses internet ni subagentes. Confirma qué has comprobado.','reasoning':{'effort':'low'}},'environment':{'type':'openai_hosted'},'input':'Crea el archivo de prueba y confirma el resultado en dos frases.','stream':True}
    with req('/agents/sessions','POST',body) as r:
        report['http_status']=r.status
        payload=[]
        for line in r:
            line=line.decode().rstrip('\r\n')
            if line.startswith('data:'):payload.append(line[5:].lstrip())
            elif not line and payload:
                event=json.loads('\n'.join(payload)); payload=[]; kind=event.get('type','')
                if kind=='agent.session.created':sid=event['session']['id'];report['session_id']=sid;print('Hosted session created.',flush=True)
                turn=event.get('turn',{})
                if kind=='agent.session.turn.started' and turn.get('subagent_id') is None:tid=turn['id'];report['turn_id']=tid
                if kind.endswith('output_text.done') and event.get('subagent_id') is None:report.setdefault('output',[]).append(event.get('text',''))
                if kind in ('agent.session.turn.completed','agent.session.turn.failed','agent.session.turn.cancelled') and turn.get('subagent_id') is None:
                    report['turn_status']=turn.get('status',kind.rsplit('.',1)[-1]);report['error']=turn.get('error');break
                if kind in ('error','agent.session.failed','agent.session.environment.failed'):
                    report['error']=event.get('error',event.get('session',{}).get('error'));break
    if sid:
        report['turns']=get('/agents/sessions/'+sid+'/turns?limit=5')['data']
        arts=get('/agents/sessions/'+sid+'/artifacts?limit=100').get('data',[])
        report['artifacts']=[{'id':a.get('id'),'path':a.get('path')} for a in arts]
        for a in arts:
            if a.get('path','').endswith('/aster-check.txt'):
                with req('/agents/sessions/'+sid+'/artifacts/'+a['id']+'/content') as r:content=r.read(10000).decode()
                report['file_verified']=content.strip()=='ASTER_OK_2026'
except Exception as e:report['failure']=str(e).replace(key,'[redacted]')
finally:
    if sid:
        try:
            with req('/agents/sessions/'+sid,'DELETE') as r:report['cleanup_status']=r.status
        except Exception as e:report['cleanup_error']=str(e).replace(key,'[redacted]')
    report['elapsed_seconds']=round(time.monotonic()-started,2)
    (root/'work/aster-live-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k not in ('turns','available_models')},ensure_ascii=False).replace(key,'[redacted]'),flush=True)
