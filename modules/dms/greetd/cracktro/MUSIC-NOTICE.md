# Crédit musique — cracktro login

`a-night-of-dizzy-spells.mp3`

- **Titre** : A Night Of Dizzy Spells
- **Album** : Resistor Anthems
- **Auteur** : Eric Skiff — https://ericskiff.com/music/
- **Licence** : Creative Commons Attribution 4.0 (CC-BY)
  → redistribuable (y compris embarqué dans Humanix) à condition de créditer l'auteur.

Attribution reproduite dans le **scroller** du cracktro (« MUSIC BY ERIC SKIFF –
RESISTOR ANTHEMS – CC-BY ») et ici.

## Changer de morceau
```nix
humanix.login.cracktro.music = ./mon-fichier.mp3;   # ou .ogg .flac .wav
# ou un vrai module tracker Amiga :
humanix.login.cracktro.music = ./ma-tune.mod;        # .mod .xm .it .s3m .med …
```
Le lecteur est auto-détecté : **xmp** pour les modules tracker, **mpv** pour le reste.
