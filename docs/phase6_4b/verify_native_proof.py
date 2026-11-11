"""Verify only the public synthetic Android QA proof, independently of Dart."""
import base64
import hashlib
import json
import re
from pathlib import Path
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ec

folder = Path(__file__).resolve().parent
log = folder/'runtime/android-initial.log'
text = log.read_text(encoding='utf-8-sig')
proof = json.loads(re.search(r'BK_NATIVE_PROOF:(\{[^\r\n]+\})',text).group(1))
assert proof['message'] == 'BK-DEVICE/v1\nenroll\n00000000-0000-4000-8000-000000000000\nsynthetic-native-nonce'
public = serialization.load_der_public_key(base64.b64decode(proof['public_key']))
assert isinstance(public, ec.EllipticCurvePublicKey) and isinstance(public.curve,ec.SECP256R1)
public.verify(base64.b64decode(proof['signature']),proof['message'].encode(),ec.ECDSA(hashes.SHA256()))
result = {'test_only':True,'device_type':'Android emulator, not physical phone',
    'public_proof':proof,'verification':'passed','algorithm':'P-256 / SHA-256 / DER ECDSA',
    'source_log_sha256':hashlib.sha256(log.read_bytes()).hexdigest()}
(folder/'NATIVE_PROOF_VERIFICATION.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('Synthetic Android proof verified with Python cryptography.')
