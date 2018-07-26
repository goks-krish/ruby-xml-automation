#! /bin/sh
cur=$pwd
cd /home/goks/Development/Working/medhand_Petr/content/
#len=${#cmb}
book=$1
d=${book##com.medhand.books.}
echo $d
mkdir $d
cd $d
split -b 500k ../$book y
cd $cur

