## 0.1.6
* Add a settable logging global, which prints to console by default

## 0.1.5
* Fix the "catchError expecting arguments" bug

## 0.1.4
* Bug fixes, including the slider min-max assertion bug and one more "property unavailable"

## 0.1.3
* Various bug fixes
* Remove Windows (mpv_dart apparently doesn't support it) and add Fedora

## 0.1.2
* Fix "property unavailable" bug
* Update README

## 0.1.1
* Work around the app restarting on the last thing that was played
* Concatenation insert/remove/move support

## 0.1.0
* Ok so it was here after all, because I forgot to start it and make sure it was started. So that's fixed now.
* The "idle" state is more or less a "done" state, so I've made it not assume that it's done while it loads. So the player doesn't kill itself after every track now.
* In short, it should now work! (Note: it is undertested against network sources atm)

## 0.0.1-pre.1

* Pretty much all of the features.
* Not sure where the problem with load() not being called is but I'm pretty sure it's not here.
