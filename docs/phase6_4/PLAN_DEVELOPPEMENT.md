# Plan progressif proposé — livrable 9

**Aucun lot d’implémentation n’est autorisé par ce document.** Chaque lot demande
validation de son périmètre, code réversible et preuves avant le suivant. Toutes
les premières transactions et annonces sont fictives ; production reste bloquée.
Complexité relative, pas estimation de jours ou de recettes financières.

| Lot futur | Périmètre minimal | Dépendance et acceptation | Complexité |
|---|---|---|---|
| M0 — décisions | Gratuit protégé, avantages nouveaux, pays/porteur, canaux, audience, fenêtre hors ligne/reboot et règles d’approbation | Approbation des dix livrables et des arbitrages ; pas de prix proposé automatiquement | Faible en code, décision humaine nécessaire |
| M1 — preuve crypto isolée | Signature/vérification Python/Dart avec identités, clés et droits synthétiques ; ancre native et tests de reboot | Vecteurs connus et protocole revus, mesures sur Android cible, limites explicites ; aucune table commerciale ni SDK live | Moyenne/élevée |
| M2 — identité et isolation | Sessions Django mobiles, stockage sûr, CSRF, changement guest/A/B, contextes locaux de progression/SRS/droits | Aucun rattachement automatique ; conservation/backup des clés locales ; tests comptes/session/401/retour hors ligne | Élevée, prérequis absolu mobile |
| M3 — noyau droits/Admin | Sous-ensemble catalogue gratuit protégé, grants fictifs/geste/bourse, état compte, audit et permissions | Migrations additives sur copie, contraintes de concurrence PostgreSQL, accès objets ; pas d’encaissement | Moyenne |
| M4 — leases et API personnelle | Emission limitée, clés appareils, révocation/renouvellement, stockage scoped et web lecture de droits | M1–M3, rotation staging/prod, panne serveur et perte d’appareil ; aucune donnée supprimée | Élevée |
| M5 — paiements manuels simulés | Méthodes et coordonnées factices, demandes/devis, rapprochement simulé, approbation et outbox | Permissions, reçu unique vérifié, deux approbations concurrentes, montants/devises, pièces privées ; blocages 6.3 pris en compte | Moyenne/élevée |
| M6 — UX de compte et notifications | Consultation des droits/demandes, messages de statut et simulations web/Flutter ; pas de tunnel Store non autorisé | Identité opérationnelle, revue petits écrans/accessibilité/Erfe, aucun tarif local codé | Moyenne |
| M7 — sponsors sans SDK | Placement factice clairement identifié, fréquence et exclusions, kill switch | 0 annonce par défaut/Premium/contexte sensible ; créatif sans tracking | Moyenne |
| M8 — adaptateur Ads test | Un seul fournisseur retenu, IDs de test, UMP/âge, faux rewarded ou SSV de test si approuvé | Audience/pays/filtrage revus ; mesurer APK, startup, mémoire et réseau avant/après | Élevée, facultative |
| M9 — PSP/Store sandbox | Un seul canal approuvé, preuves fournisseur et notifications, restauration/remboursements | Compte et conditions éligibles, distinction test/live, aucun secret dans app/API publique ; revue de publication | Élevée, facultative |
| M10 — préproduction | Recette réelle et décision de déploiement séparée | Lever les blocages 6.3, sauvegardes cloud testées, revue humaine et autorisation explicite | Dépend de l’infrastructure réelle |

Les lots M1/M2 lèvent les inconnues avant de construire un grand catalogue
commercial. Le schéma cible n’impose pas de créer seize modèles en une fois.
ProviderEvent et campagnes complètes sont différés jusqu’au fournisseur/usage réel.
L’authentification n’est pas « un bouton login » : le cache pédagogique actuel et
les transitions de propriétaire doivent être recettés avant les achats mobiles.

## Réutilisation et dépenses

Conserver le monolithe Django/DRF, PostgreSQL, Admin, stockage privé et cache partagé.
Outbox traitée par une commande périodique approuvée ; pas de broker obligatoire.
Pas de nouveau service de reconnaissance vocale, de DRM massif ou d’analyse
comportementale. Les bibliothèques crypto et stockage sécurisé sont des ajouts
possibles à justifier et tester, **pas des dépendances déjà ajoutées**.

Ne choisir ni fournisseur à commission ni nouvelle ressource payante avant de
connaître pays marchand, contrat, usage, volume et budget. Aucun revenu publicitaire
ou coût d’exploitation supplémentaire n’est chiffré sans preuve. Vérifier que les
SDK proposés n’excluent pas les versions Android/supports actuels ; si leur minSdk
ou taille change, soumettre l’impact à validation au lieu de le masquer.

## Livrable attendu pour chaque lot autorisé

Fichiers modifiés, cause/contrats, tests de reproduction puis résultats réels,
impact DB/API, captures si UI, métriques si optimisation, risques et retour arrière.
Comptes/transactions/annonces synthétiques uniquement jusqu’à une autorisation
commerciale distincte. Un test vert n’autorise ni migration de production ni
publication Store. Les fonctions éducatives existantes restent utilisables sur
un ancien client ou si le service commercial est désactivé.

## Arbitrages à obtenir maintenant

1. Confirmer le socle gratuit et choisir les seuls avantages nouveaux à étudier.
2. Accepter ou ajuster la proposition de sept jours hors ligne et la revalidation
   après reboot du téléphone ; décider le nombre d’appareils et la récupération.
3. Confirmer l’identité par sessions et la stratégie de migration locale guest/A/B.
4. Déterminer porteur/pays, canaux initiaux et audience ; fournir ultérieurement
   les coordonnées officielles via un canal approprié, jamais une clé dans un rapport.
5. Fixer les rôles et le double contrôle ; aucun achat réel ni prix à définir ici.

**Ordre recommandé : valider M0, autoriser ensuite un seul petit lot, pas M1–M10
en bloc.** Aucune de ces décisions n’est assimilée à une activation commerciale.
