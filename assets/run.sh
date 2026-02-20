#!/bin/bash

rm markdowner.png
./svg2appiconset.sh markdowner.svg
mv AppIcon.appiconset/icon_mac512.png ./markdowner.png
rm -Rf AppIcon.appiconset
./clear_icon_cache.sh
cd ..
flutter clean && flutter pub get
cd assets