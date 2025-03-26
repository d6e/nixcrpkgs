source $setup

# Use --warning=no-unknown-keyword to ignore the LIBARCHIVE.xattr warnings
tar -xf $src --warning=no-unknown-keyword
mv MacOSX*.sdk $out

cd $out

ruby -rjson \
  -e "print JSON.load(File.read('SDKSettings.json')).fetch('Version')" \
  > version.txt

# Make sure the STL headers are in the expected place.
if [ -d usr/include/c++/v1 ]; then
  mkdir -p usr/include/c++/
  cp -a usr/include/c++/v1/* usr/include/c++/
  # Use rm -rf instead of rmdir to handle non-empty directory
  rm -rf usr/include/c++/v1
fi
ls usr/include/c++/iterator > /dev/null
