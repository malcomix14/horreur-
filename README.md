# VESPÉRINE — *Celui qui veille*

Jeu d'horreur à la première personne pour **Godot 4 (4.3 ou plus récent)**, écrit en GDScript typé.
Vous vous réveillez dans le manoir abandonné des Vespérine. Un grand corps maigre aux yeux sans
paupières marche dans les couloirs. Il ne dort jamais. Trouvez les quatre clés de la grande porte… et fuyez.

- Aucun fichier externe : **tout est généré par code** (géométrie du manoir, mobilier, monstre,
  textures, sons, musique). Aucun plugin, aucun téléchargement.
- Pensé pour les **PC modestes** (renderer *Compatibility*, une seule lumière avec ombres : la lampe torche).

---

## 1. Ouvrir et lancer

1. Installez Godot **4.3 ou plus récent** (version standard, pas besoin de la version .NET) : <https://godotengine.org/download>.
2. Dans le gestionnaire de projets : **Importer** → choisissez le fichier `project.godot` de ce dossier → **Importer et modifier**.
   (Si Godot propose de convertir le projet vers une version plus récente, acceptez.)
3. Appuyez sur **F5** (ou le bouton ▶). La scène principale (`scenes/main.tscn`) est déjà configurée.

**Premier lancement :** le jeu génère ses textures et ses sons (écran « Préparation du manoir… »).
Comptez environ 5 à 15 secondes sur un i3. Ils sont ensuite **mis en cache** dans le dossier utilisateur
(`%APPDATA%\Godot\app_userdata\vesperine\cache` sous Windows) : les lancements suivants sont quasi instantanés.
Vous pouvez supprimer ce dossier `cache` sans risque, il sera recréé.

## 2. Contrôles

Les touches sont liées à leur **position physique** : **ZQSD (AZERTY) et WASD (QWERTY) fonctionnent tous les deux**, sans réglage.

| Action | Touche |
|---|---|
| Se déplacer | ZQSD / WASD / flèches |
| Regarder | Souris |
| Courir (endurance limitée) | Maj |
| S'accroupir | Ctrl (maintenir) ou C (bascule) |
| Interagir / ramasser / lire / se cacher | E ou clic gauche |
| Lampe torche | F ou clic droit |
| Changer la pile | R |
| Journal (inventaire, documents, objectif) | Tab (ou J / I) |
| Pause / options | Échap (ou P) |
| Afficher les FPS | F3 |

## 3. Règles de survie

- **Le Veilleur ne tue pas en vous voyant.** Il vous tue seulement s'il **vous attrape** (contact après une poursuite).
- Quand il vous repère, il **hurle** avant de charger : c'est votre avance. Il est un peu plus lent que vous
  quand vous courez, mais votre endurance est limitée.
- **Fermez les portes** derrière vous : il doit les enfoncer, ce qui le ralentit (et vous prévient).
- **Cachez-vous** (armoires, placards, sous les lits, confessionnal) **hors de sa vue**. S'il vous a vu entrer,
  il viendra vous en arracher.
- Il **entend** : courir, claquer une porte, faire démarrer une machine ou une boîte à musique l'attire.
  Accroupi, vous êtes presque silencieux. Lampe éteinte, il vous voit de moins loin.
- Son **souffle**, ses **pas** et vos **battements de cœur** vous indiquent sa proximité.
- Après chaque fouille infructueuse, il s'éloigne un moment : profitez-en.
- La progression est **sauvegardée automatiquement** à chaque clé et étape importante. En cas de capture :
  « Réessayer » reprend au dernier point de sauvegarde.

## 4. Histoire (sans spoiler)

Novembre 1954, Morvan. Clerc de l'étude Fauvel, vous êtes venu dresser l'inventaire du manoir Vespérine,
fermé depuis la disparition de toute la famille en 1938 : le docteur Aurèle, son épouse Madeleine,
leur fille Lise, huit ans, et Gaspard, le majordome dévoué. À peine entré, la porte s'est refermée derrière vous.
Puis plus rien.

L'histoire se découvre à travers **14 documents** (journaux, lettres, dessins, coupures de presse) et les objets du manoir.
Il y a **deux fins**.

## 5. Réglages pour PC faible (ex. Intel i3 N305, 8 Go, iGPU)

Le projet utilise déjà le renderer **Compatibility** (OpenGL 3.3), sans SDFGI, SSR, SSAO, glow ni brouillard volumétrique.
Au **premier lancement**, si une carte graphique intégrée est détectée (Intel UHD/Iris, Radeon intégrée…), le jeu choisit
automatiquement : résolution 3D 65 %, qualité Moyenne, 60 FPS max.
Dans **Options** (menu principal ou pause) :

- Bouton **« Préréglage PC faible »** : résolution 3D 60 %, qualité Basse, ombres de la lampe désactivées,
  30 FPS max, compteur FPS affiché. C'est le meilleur point de départ si ça rame.
- **Résolution 3D** (40–100 %) : le levier le plus efficace. 60–75 % reste très lisible grâce au grain.
- **Qualité** : *Basse* = post-traitement sans lecture d'écran, pas de poussière, 6 lampes actives max, brouillard plus dense
  (moins de géométrie visible) ; *Moyenne* = 8 lampes, grain/étalonnage ; *Haute* = 10 lampes, aberration chromatique.
- **Luminosité** (50–200 %) : règle la lumière ambiante, le clair de lune et l'exposition. Si vous distinguez mal le décor
  sur votre écran, montez-la un peu ; le jeu reste sombre même à 130 %.
- **Ombres de la lampe** : la seule lumière qui projette des ombres. La couper fait gagner beaucoup sur iGPU.
- **Images/s max** : 30 stabilise la machine et évite la surchauffe ; 60 si elle suit.
- **Plein écran** et **VSync** : à tester chez vous (la VSync peut limiter à 60).

Mesures faites sur le rendu Compatibility (vues les plus chargées : galerie de 44 m, grand hall) : environ 480–520 appels de dessin
sans l'ombre de la lampe, ~660–690 avec (dont une pré-passe de profondeur qui double les appels mais évite de calculer l'éclairage
des pixels cachés), 75 000 à 140 000 triangles. L'ombre de la lampe coûte donc ~40 % d'appels en plus : c'est la première
chose à couper si ça rame.

Optimisations intégrées : géométrie fusionnée par pièce et par matériau (les matériaux qui ne diffèrent que par la couleur
partagent une même surface, teinte cuite dans les sommets), textures
générées en 64–256 px, occlusion culling par boîtes sur les murs, lumières d'ambiance sans ombres activées seulement
près du joueur, animation du monstre coupée quand il est loin, fausse occlusion ambiante « cuite » dans les couleurs de sommets,
rais de lune et halos en géométrie additive (pas de volumétrique).

### Éclairage : sombre mais jouable
Le manoir est volontairement sombre, mais **aucune zone n'est totalement noire**, même lampe torche éteinte :
- une **lumière ambiante froide** faible mais présente partout, un **clair de lune diffus** (lumière directionnelle
  sans ombre, qui distingue murs, sols et meubles par leur orientation) et un **brouillard bleuté** qui détache les
  silhouettes au loin au lieu de les noyer dans le noir ;
- environ **70 sources crédibles** : appliques à bougie, ampoules défaillantes, candélabres, bougies sur les meubles,
  lanternes et soupiraux dans les caves, grands cierges dans la chapelle, lampadaire du salon, et un **clair de lune froid**
  derrière la plupart des fenêtres. Les pièces gardent des zones chaudes et des coins plus sombres ;
- les **objets utiles** (clés, fusible, manivelle, piles, allumettes…) ont un petit **reflet pulsant**, et les documents
  pas encore lus un reflet froid plus discret ;
- seule la lampe torche projette des ombres (coût GPU) ; les lampes du manoir s'allument et s'éteignent en fondu
  selon la distance, en privilégiant celles de la pièce où vous êtes.

Relevé automatique (lampe torche éteinte, grille de points tous les 2,5 m, 4 directions, image finale 0–255) :
luminosité moyenne par pièce passée de **0,1–14** (quasi noir) à **28–68**. Les caves sans courant restent les plus sombres
(~30), la salle de bain carrelée la plus claire (~68). Pour tout éclaircir ou assombrir d'un coup :
`AMBIENT_ENERGY` / `MOON_FILL_ENERGY` dans `scripts/core/game_world.gd` et `ENERGY_SCALE` dans `scripts/level/flicker_light.gd`.

## 6. Personnaliser

### Sons
Tous les sons sont synthétisés au premier lancement. Pour remplacer un son, déposez un fichier dans `res://audio/`
portant **exactement** le même nom : `audio/<nom>.ogg` (ou `.wav` / `.mp3`). Il sera utilisé en priorité ;
si un fichier manque, le son procédural est utilisé (le jeu ne plante jamais).
Noms disponibles (voir `scripts/audio/sound_synth.gd`) :
`step_wood_1..3`, `step_stone_1..2`, `step_monster_1..2`, `breath_monster`, `monster_scream`, `monster_growl`,
`heartbeat`, `door_open`, `door_close`, `door_slam`, `door_bash`, `door_locked`, `pickup`, `key_pickup`, `paper`,
`flash_on`, `flash_off`, `battery`, `lever`, `fuse`, `power_on`, `elevator`, `safe_beep`, `safe_error`, `safe_open`,
`match`, `candle_out`, `music_box`, `whisper_1`, `whisper_2`, `giggle`, `sting_high`, `sting_low`, `scream`, `bang`,
`knock`, `glass`, `thunder`, `wind_loop`, `drone_loop`, `tension_loop`, `chase_loop`, `clock_tick`, `clock_chime`,
`drip`, `fire_loop`, `buzz_loop`, `creak_1..3`, `ui_hover`, `ui_click`, `capture`, `victory`, `breath_player`,
`hide`, `footsteps_above`, `whoosh`, `static`.

### Screamers
Tous les screamers sont décrits dans **`data/jumpscares.json`** (18 au total : 9 aléatoires, 9 déclenchés par une action).
Réglages globaux (`settings`) : délai avant le premier, intervalle de tirage, probabilité, écart minimal entre deux screamers.
Chaque entrée : `effect`, `sound`, `volume`, `shake` (secousse 0–1), `flash`, `duration`, `zones`, `weight`, `cooldown`, `max_uses`.
Les aléatoires ne se déclenchent **jamais pendant une poursuite**, jamais deux fois de suite, jamais à moins de 75 s d'intervalle.

### Textes
Les documents sont dans **`data/notes.json`**, les objets dans **`data/items.json`** (UTF-8, modifiables librement).

## 7. Exporter en .exe (Windows)

1. Menu **Éditeur → Gérer les modèles d'exportation** → **Télécharger et installer** (une seule fois, ~1 Go).
2. Menu **Projet → Exporter…** → **Ajouter… → Windows Desktop**.
3. Onglet **Ressources** : laissez « Exporter toutes les ressources du projet ». Dans **Filtres pour exporter des fichiers
   non-ressources**, ajoutez `data/*.json` (précaution : les fichiers de données doivent être inclus).
4. **Exporter le projet** → choisissez par ex. `export/Vesperine.exe`. Gardez le `.pck` à côté du `.exe`
   (ou cochez « Intégrer le PCK » pour un seul fichier).

## 8. Architecture du code

```
scenes/main.tscn                 Scène principale (nœud MainController)
scripts/autoload/                Singletons : Events (bus de signaux), Settings, GameManager (état, inventaire, drapeaux),
                                 SaveSystem, Assets (textures + matériaux), AudioManager (sons, pools, musique dynamique)
scripts/core/                    main.gd (menus, pause, flux), game_world.gd (monde, navmesh, fin), ambience_director.gd,
                                 input_setup.gd (touches physiques), layers.gd
scripts/level/                   manor_layout.gd (plan), manor_builder.gd (murs/sols/fenêtres), manor_content.gd (pièces),
                                 prop_factory.gd (mobilier), mesh_batcher.gd, texture_factory.gd, flicker_light.gd, light_manager.gd
scripts/player/                  player.gd, flashlight.gd, interaction_system.gd, inventory.gd
scripts/monster/                 monster.gd (IA à états), monster_body.gd (modèle + animation procédurale)
scripts/interactables/           porte, objet, document, cachette, tiroir, énigmes (fusible, monte-charge, coffre,
                                 boîte à musique, cierges, bibliothèque secrète, cheminée, grande porte)
scripts/jumpscare/               jumpscare_manager.gd
scripts/audio/sound_synth.gd     synthèse procédurale de tous les sons
scripts/ui/                      HUD, menus, options, lecture, pavé numérique, journal, écrans de fin, post-traitement
scripts/debug/autotest.gd        test automatique (développement uniquement)
shaders/                         post-traitement, vue depuis une cachette, fond du menu
data/                            items.json, notes.json, jumpscares.json
```

IA du monstre : **Patrouille** (points de passage, avec un « directeur » qui le rapproche du joueur s'il ne l'a pas croisé
depuis longtemps) → **Enquête** (bruit, silhouette entrevue ; jauge de détection selon la distance, la lampe, l'accroupissement)
→ **Poursuite** (cri, mémoire de 3 s après perte de vue) → **Capture** (contact) ; ou **Recherche** autour de la dernière
position connue, puis retraite. Vue = cône + rayons (les portes fermées bloquent la vue), ouïe = événements sonores,
déplacement = `NavigationAgent3D` sur un navmesh calculé au chargement.

## 9. Ce qui a été vérifié

- Le projet a été importé et exécuté en ligne de commande avec **Godot 4.3** et **Godot 4.7.2** (Linux), avec tous les
  avertissements GDScript importants (typage, division entière, variables inutilisées, masquage, conversions…) **promus en erreurs** :
  aucune erreur.
- Un **test automatique** (`scripts/debug/autotest.gd`) joue une partie complète par code : navmesh (tous les points de patrouille
  atteignables, cave accessible, cabinet secret fermé puis ouvert), portes, lecture, tiroirs, fusible → monte-charge,
  coffre (mauvais puis bon code), boîte à musique, cierges (mauvais puis bon ordre), bibliothèque secrète, registre brûlé,
  pile, poursuite et capture, reprise de sauvegarde, cachette non vue (pas trouvé) et vue (arraché), les 18 screamers,
  menus, options, pause et fin « Délivrance ». Résultat : **112 vérifications, 0 échec** sous 4.3 comme sous 4.7.2.
- Les sons synthétisés ont été contrôlés par analyse (niveaux, saturation, silence, spectres), pas à l'oreille.
- Des captures d'écran ont été produites avec le renderer Compatibility sur un rendu logiciel (Mesa llvmpipe) pour contrôler l'image.

Pour relancer ce test : `godot --path . --fixed-fps 60 -- --autotest` (ajouter `--headless` pour ne rien afficher).
Pour mesurer les appels de dessin sur votre machine : `godot --path . -- --autotest --perf` (lignes `PERF` dans la console).
Pour relever la luminosité de chaque pièce (lampe torche éteinte) : `godot --path . --fixed-fps 60 -- --autotest --lumi`
(lignes `LUMI` ; ajouter `--shots=/un/dossier` pour enregistrer les vues les plus sombres).

**Non vérifié** (à tester chez vous) : les performances réelles sur votre i3 N305, le rendu exact sur un vrai GPU Intel,
le son (la machine de test n'avait pas de carte son : les sons ont été générés et joués mais pas écoutés),
le ressenti de la souris et de la difficulté, l'export .exe.

---

## 10. ⚠️ SPOILERS — Solution complète

<details>
<summary>Cliquez pour afficher la solution</summary>

**Départ** : salle à manger. Lampe torche et lettre sur la table. ~20 s après avoir pris la lampe, le Veilleur se réveille
dans la chapelle (nord).

**Clé de fer (Gaspard)** — cave
1. Dans la cuisine, la note près de la trappe du monte-charge indique où sont les fusibles.
2. **Fusible** : tiroir de la table de chevet, chambre de Gaspard (au sud-est, par le salon).
3. Descendez à la cave par l'escalier de la cuisine. **Boîtier électrique** : mur nord de la cave à vin → le courant revient.
4. **Monte-charge** : cave (sous la cuisine), mur est. Appelez-le (très bruyant !) → la clé de fer est dans la cabine.

**Clé d'argent (Aurèle)** — bureau
- Coffre-fort du bureau (nord). Indices : note d'Aurèle sur le bureau (« le jour, puis le mois » de la naissance de Lise)
  + carte d'anniversaire dans la chambre de Lise (14 mars). **Code : 1403**. En prenant la clé, noir total…

**Clé de laiton (Lise)** — chambre de Lise
1. **Manivelle** : bibliothèque, sur le guéridon près du fauteuil (indice : l'étiquette de la boîte à musique).
2. Remontez la **boîte à musique** de Lise : elle joue ~17 s, fort — le Veilleur arrive. À la fin, un tiroir secret s'ouvre.

**Clé d'os (Madeleine)** — chapelle
1. **Allumettes** : un tiroir du plan de travail de la cuisine (un autre tiroir cache une mauvaise surprise).
2. Journal de Madeleine III sur le lutrin de la chapelle : allumer **le Père, puis la Mère, puis l'Enfant**.
   Chandeliers de gauche à droite : l'Enfant, le Père, la Mère. Mauvais ordre = tout s'éteint.
3. Le dessus de l'autel glisse : la clé d'os.

**Fin 1 — « Évasion »** : les 4 clés dans la serrure de la grande porte (hall, au sud).

**Fin 2 — « Délivrance » (vraie fin)** :
1. Journal de Madeleine I (salon) : le **livre rouge** de la bibliothèque est un levier (étagère basse du mur sud, à gauche de la porte).
2. Le **cabinet secret** s'ouvre : le **Registre de la Veille** et la dernière lettre d'Aurèle.
3. Brûlez le registre dans la **cheminée du salon** (il faut les allumettes). Le Veilleur devient fou de rage (plus rapide).
4. Fuyez par la grande porte avec les 4 clés.

**Piles** : buffet de la salle à manger, tiroir de la cuisine, console de la galerie, bureau, table de chevet de la chambre
des maîtres, établi de la cave à vin, cabinet secret.

**Cachettes** : placards (salle à manger, cuisine, bibliothèque, bureau, salon, sous l'escalier du hall), armoires
(galerie, couloir ouest, chambre des maîtres, chambre de Lise, deux à la cave), sous le lit (chambre des maîtres,
chambre de Gaspard), confessionnal (chapelle).

</details>
