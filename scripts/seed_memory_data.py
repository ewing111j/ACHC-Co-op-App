#!/usr/bin/env python3
"""
Seed Firestore with Memory Work static data:
- cycles (cycle_1, cycle_2, cycle_3)
- subjects (11 subjects)
- memory_settings (global active cycle + unit)

Run: python3 /home/user/flutter_app/scripts/seed_memory_data.py
"""

import sys
import os

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("Installing firebase-admin...")
    os.system("pip install firebase-admin==7.1.0 -q")
    import firebase_admin
    from firebase_admin import credentials, firestore

# ── Init ──────────────────────────────────────────────────────────────────────
admin_key_paths = [
    '/opt/flutter/firebase-admin-sdk.json',
    '/opt/flutter/service-account.json',
]

cred_path = None
for p in admin_key_paths:
    if os.path.exists(p):
        cred_path = p
        break

if cred_path is None:
    # Try to find any adminsdk file
    for f in os.listdir('/opt/flutter'):
        if 'adminsdk' in f.lower() or 'firebase' in f.lower():
            cred_path = f'/opt/flutter/{f}'
            break

if cred_path is None:
    print("ERROR: No Firebase Admin SDK key found in /opt/flutter/")
    print("Upload your firebase-admin-sdk.json to the Firebase tab first.")
    sys.exit(1)

print(f"Using credential: {cred_path}")
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)
db = firestore.client()

# ── Cycles ────────────────────────────────────────────────────────────────────
print("Seeding cycles...")
cycles = [
    {'id': 'cycle_1', 'name': 'Cycle 1', 'is_active': False, 'activated_at': None},
    {'id': 'cycle_2', 'name': 'Cycle 2', 'is_active': True,  'activated_at': firestore.SERVER_TIMESTAMP},
    {'id': 'cycle_3', 'name': 'Cycle 3', 'is_active': False, 'activated_at': None},
]
for c in cycles:
    doc_id = c.pop('id')
    db.collection('cycles').document(doc_id).set(c, merge=True)
    print(f"  ✅ {doc_id}")

# ── Subjects ──────────────────────────────────────────────────────────────────
print("Seeding subjects...")
subjects = [
    {'id': 'religion',     'name': 'Religion',       'icon': '✝️',  'color': '#8B0000', 'content_type': 'A', 'sort_order': 0},
    {'id': 'scripture',    'name': 'Scripture',      'icon': '📖',  'color': '#4A0080', 'content_type': 'B', 'sort_order': 1},
    {'id': 'latin',        'name': 'Latin',          'icon': '🏛️', 'color': '#1B2A4A', 'content_type': 'B', 'sort_order': 2},
    {'id': 'grammar',      'name': 'Grammar',        'icon': '✏️',  'color': '#004D40', 'content_type': 'A', 'sort_order': 3},
    {'id': 'history',      'name': 'History',        'icon': '🏰',  'color': '#4E342E', 'content_type': 'B', 'sort_order': 4},
    {'id': 'science',      'name': 'Science',        'icon': '🔬',  'color': '#0D47A1', 'content_type': 'A', 'sort_order': 5},
    {'id': 'math',         'name': 'Math',           'icon': '➕',  'color': '#1B5E20', 'content_type': 'C', 'sort_order': 6},
    {'id': 'geography',    'name': 'Geography',      'icon': '🌍',  'color': '#006064', 'content_type': 'C', 'sort_order': 7},
    {'id': 'great_words_1','name': 'Great Words I',  'icon': '💬',  'color': '#E65100', 'content_type': 'B', 'sort_order': 8},
    {'id': 'great_words_2','name': 'Great Words II', 'icon': '📝',  'color': '#880E4F', 'content_type': 'B', 'sort_order': 9},
    {'id': 'timeline',     'name': 'Timeline',       'icon': '⏳',  'color': '#37474F', 'content_type': 'B', 'sort_order': 10},
]
for s in subjects:
    doc_id = s.pop('id')
    db.collection('subjects').document(doc_id).set(s, merge=True)
    print(f"  ✅ {doc_id}")

# ── Units for cycle_2 ─────────────────────────────────────────────────────────
print("Seeding units for cycle_2...")

content_units = [1,2,3,5,6,7,9,10,11,19,20,21,23,24,25,27,28,29]
review_units  = [4,8,12,22,26,30]
break_units   = list(range(13, 19))  # 13-18

all_units = []
for n in range(1, 31):
    if n in content_units:
        utype = 'content'
    elif n in review_units:
        utype = 'review'
    elif n in break_units:
        utype = 'break'
    else:
        utype = 'content'  # fallback
    all_units.append({
        'unit_number': n,
        'unit_type': utype,
        'cycle_id': 'cycle_2',
        'label': f'Unit {n}',
    })

for u in all_units:
    doc_id = f"cycle_2_unit_{str(u['unit_number']).zfill(2)}"
    db.collection('units').document(doc_id).set(u, merge=True)
print(f"  ✅ 30 units seeded for cycle_2")

# ── Memory Settings (global) ──────────────────────────────────────────────────
print("Seeding memory_settings...")
db.collection('memory_settings').document('global').set({
    'active_cycle_id': 'cycle_2',
    'current_unit': 1,
}, merge=True)
print("  ✅ memory_settings/global")

print("\n🎉 Memory Work seed data complete!")
print("Next: Import memory item content via ContentManagerScreen CSV import.")
