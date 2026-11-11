"""Public deterministic TEST vector, never usable as a production key.

RFC8032 test seed and synthetic identity. No private key file is produced.
"""
import base64
import hashlib
import json
import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test',
                  SECRET_KEY='synthetic-vector-only', DATABASE_URL='sqlite:///:memory:')
import django
django.setup()
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, ec
from monetization.licensing import sign_claims

key = ed25519.Ed25519PrivateKey.from_private_bytes(bytes.fromhex(
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'))
device = ec.derive_private_key(7, ec.SECP256R1()).public_key().public_bytes(
    serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
claims = {'version':1,'issuer':'bk','audience':'bk-android-simulation','environment':'test',
    'subject':'11111111-1111-4111-8111-111111111111','lease_id':'22222222-2222-4222-8222-222222222222',
    'entitlement_epoch':4,'device_id':'33333333-3333-4333-8333-333333333333',
    'device_key_thumbprint':hashlib.sha256(device).hexdigest(),
    'features':['simulation.badge'],'grant_ids':['44444444-4444-4444-8444-444444444444'],
    'issued_at':1900000000,'starts_at':1900000000,'server_now':1900000000,
    'expires_at':1900604800,'offline_valid_until':1900604800,
    'nonce':'synthetic-fresh-challenge','policy_version':1}
result = {'test_only':True, 'public_key_b64':base64.b64encode(key.public_key().public_bytes(
    serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode(),
    'device_public_key_b64':base64.b64encode(device).decode(), 'claims':claims,
    'envelope':sign_claims(claims, key, 'sim-rfc8032-test')}
result['variants'] = {}
for name, changes in {
    'revoked':{'entitlement_epoch':5,'features':[],'grant_ids':[], 'nonce':'revoked-fresh',
        'lease_id':'55555555-5555-4555-8555-555555555555',
        'issued_at':1900000010,'starts_at':1900000010,'server_now':1900000010,
        'expires_at':1900000010,'offline_valid_until':1900000010},
    'stale_epoch':{'entitlement_epoch':3,'nonce':'stale-fresh'},
    'too_long':{'expires_at':1900604801,'offline_valid_until':1900604801},
    'unknown_feature':{'features':['alphabet.paid']},
    'wrong_subject':{'subject':'99999999-9999-4999-8999-999999999999'},
}.items():
    result['variants'][name] = sign_claims({**claims,**changes}, key, 'sim-rfc8032-test')
out = root/'mobile/test/fixtures/commerce_lease_test_vector.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
print('Written public synthetic fixture:', out.name)
