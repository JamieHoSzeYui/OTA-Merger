#!/bin/bash

usage()
{
echo "Usage: $0 <Full OTA> <The OTA you wanna merge> <Additional args>"
echo "Use $0 -h or $0 --help to call this message."
}

if [[ $1 = "--help" ]]; then
    usage
    exit
fi 

if [[ $1 = "-h" ]]; then
    usage
    exit
fi

if [[ ! -n $2 ]]; then
   echo "All variables needed !"
   exit
fi

# Variables

MYDIR=$(pwd .)
TOOLSDIR=$MYDIR/tools
FULL=$1
UPDATE=$2

# Check tools
if [[ $(ls tools/payload) ]]; then
    echo "Up to date."
else
    git clone -q https://github.com/cyxx/extract_android_ota_payload.git $TOOLSDIR/payload
fi

if [[ $(ls tools/sdat2img) ]]; then
    echo "Up to date."
else
    git clone -q https://github.com/xpirt/sdat2img $TOOLSDIR/sdat2img
fi

# MORE VARIABLES AAAAA
SDAT2IMG=$TOOLSDIR/sdat2img/sdat2img.py
PAYLOAD=$TOOLSDIR/payload/extract_android_ota_payload.py
OUTDIR=$MYDIR/output
TMPDIR=$MYDIR/tmp
BASEFW=$TMPDIR/base
OTAFW=$TMPDIR/ota


# Setup dirs
if [[ $(ls | grep $OUTDIR ) ]]; then
    echo "Creating temp dirs"
    rm -rf $TMPDIR 
    mkdir $TMPDIR
else
    echo "Creating temp and out dirs"
    rm -rf $TMPDIR
    mkdir $TMPDIR $OUTDIR
fi

mkdir $BASEFW $OTAFW

if [[ $(7z -l ba $FULL | grep .new.dat.br) ]]; then
    echo "[BASE] Aonly FW detected"
    if [[ $(7z -l ba $FULL | grep product.new) ]]; then
        echo "WARNING : Product partition detected"
        echo "This may be fatal in the future as tool will not merge dynamic partitions"
    fi
    echo "[BASE] Extracting FW.."
    unzip $FULL system* -d $BASEFW/ 2>/dev/null
    cd $BASEFW/
    brotli -d system.new.dat.br system.new.dat 2>/dev/null
    cd ../../
    python $SDAT2IMG $BASEFW/system.transfer.list $BASEFW/system.new.dat $OUTDIR/system.img 2>/dev/null
elif [[ $(7z -l ba $FULL | grep payload.bin) ]]; then
    echo "[BASE] : Extracting FW.." 
    unzip $FULL payload.bin -d $BASEFW/ 2>/dev/null
    python $PAYLOAD $BASEFW/payload.bin $BASEFW
    mv $BASEFW/system.img $OUTDIR/system.img
fi

if [[ $(7z -l ba $UPDATE | grep .new.dat.br) ]]; then
    echo "[OTA] Aonly FW detected"
    if [[ $(7z -l ba $UPDATE | grep product.new) ]]; then
        echo "WARNING : Product partition detected"
        echo "This may be fatal in the future as tool will not merge dynamic partitions"
    fi
    echo "[BASE] Extracting FW.."
    unzip $FULL system* -d $OTAFW/ 2>/dev/null
    cd $OTAFW/
    brotli -d system.new.dat.br system.new.dat 2>/dev/null
    cd ../../
    python $SDAT2IMG $OTAFW/system.transfer.list $OTAFW/system.new.dat $OUTDIR/merge.img 2>/dev/null
elif [[ $(7z -l ba $UPDATE | grep payload.bin) ]]; then
    echo "[UPDATE] : Extracting FW.." 
    unzip $UPDATE payload.bin -d $OTAFW/ 2>/dev/null
    python $PAYLOAD $OTAFW/payload.bin $OTAFW
    mv $OTAFW/system.img $OUTDIR/merge.img
fi

# MOREEEE VARSSSSSSS
SYSTEM=$OUTDIR/system
TEMPDIR=$OUTDIR/merge

mkdir $SYSTEM $TEMPDIR
sudo mount $OUTDIR/system.img $SYSTEM
sudo mount -o ro $OUTDIR/merge.img $TEMPDIR
if [[ $(ls $TEMPDIR | grep default.prop) ]]; then
    echo "SAR update detected"
    sudo cp -fpr $TEMPDIR/* $SYSTEM
elif [[ $(ls $TEMPDIR | grep priv-app) ]]; then
    echo "Strange shit detected"
    sudo cp -fpr $TEMPDIR/* $SYSTEM/system/
else 
    echo "BRUH : idk too"
    echo "Failed, toool doesn't know system type"
    sudo umount $OUTDIR/*
    sudo rm -rf $OUTDIR/*
    exit
fi
sudo umount $OUTDIR/*
rm -rf $SYSTEM $TEMPDIR $OUTDIR/merge.img

echo "Done !"
