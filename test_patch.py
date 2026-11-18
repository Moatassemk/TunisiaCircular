import json, urllib.request, urllib.error

# Login
login = json.loads(urllib.request.urlopen(urllib.request.Request(
    'http://localhost:5001/api/auth/login',
    data=json.dumps({'email':'djerba.beach@tn','password':'Resort123!'}).encode(),
    headers={'Content-Type':'application/json'}
).read().decode())

token = login['token']
print('Login OK, role:', login['user']['role'])

# PATCH status
req = urllib.request.Request(
    'http://localhost:5001/api/transactions/e550e0cb-4ada-42d9-945d-20dcc6b8505b/status',
    data=json.dumps({'status':'matched'}).encode(),
    headers={'Authorization': f'Bearer {token}', 'Content-Type':'application/json'},
    method='PATCH'
)
try:
    resp = urllib.request.urlopen(req)
    print('PATCH OK:', json.loads(resp.read().decode()))
except urllib.error.HTTPError as e:
    print('PATCH FAILED:', e.code, e.read().decode())