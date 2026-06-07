# Beřiyar Kedebideři

Plateforme d’apprentissage, de transmission et de valorisation de la langue Beriya Erfe.

## Vision

Beřiyar Kedebideři aide les locuteurs Beriya/Zaghawa qui parlent déjà la langue oralement à apprendre progressivement l’écriture Beriya Erfe.

Le projet repose sur trois principes :

- Audio-first
- Offline-first
- Visual-first

## Interfaces

Le projet contient :

- Backend Django REST API
- Web frontend responsive avec identité Beřiyar Kedebideři
- Application mobile Flutter offline-first
- Administration Django pour gérer le corpus

## Identité

Couleurs principales :

- Vert profond : #1B4D3E
- Vert nocturne : #0F3227
- Or transmission : #D4AF37

Signature :

Écouter. Lire. Écrire. Transmettre.

## Modules principaux

- AudioAsset
- Alphabet Beriya Erfe
- Vocabulaire
- LearningTheme / LearningUnit
- Lessons oral-first
- Quiz
- Offline Packs
- Starter Pack
- UnitProgress
- Feedback
- No Ena

## Règles importantes

- Aucun mot codé en dur dans Flutter
- Aucun quiz codé en dur dans Flutter
- Aucun contenu de démonstration dans No Ena
- Les audios sont séparés dans AudioAsset
- Les textes UI sont localisés en français, anglais et arabe
- Django REST API est la source officielle du contenu
- Flutter est prioritaire pour l’apprentissage hors connexion
- Le web est responsive et reprend l’identité visuelle de la marque