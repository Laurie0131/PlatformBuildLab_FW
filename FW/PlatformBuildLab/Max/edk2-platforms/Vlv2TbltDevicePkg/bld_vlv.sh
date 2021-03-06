#!/usr/bin/env bash
##**********************************************************************
## Function define
##**********************************************************************
function Usage() {
  echo
  echo "***************************************************************************"
  echo "Build BIOS rom for VLV platforms."
  echo
  echo "Usage: bld_vlv.sh  PlatformType [Build Target]"
  echo
  echo
  echo "       Platform Types:  MNW2"
  echo "       Build Targets:   Debug, Release  (default: Debug)"
  echo
  echo "***************************************************************************"
  echo "Press Control-C to exit......"
  read
  return 0
#  exit 0
}

cd ..
echo -e $(date)
##**********************************************************************
## Initial Setup
##**********************************************************************
export WORKSPACE=$(pwd)
#build_threads=($NUMBER_OF_PROCESSORS)+1
Build_Flags=
exitCode=0
Arch=X64
SpiLock=0
# thread count
TN=1

export CORE_PATH=$WORKSPACE/edk2
export PLATFORM_PATH=$WORKSPACE/edk2-platforms
export SILICON_PATH=$WORKSPACE/silicon
export EDK_TOOLS_BIN=$WORKSPACE/edk2-BaseTools-win32
export PACKAGES_PATH=$WORKSPACE:$PLATFORM_PATH:$SILICON_PATH:$CORE_PATH
cd ./edk2
echo $(pwd)
echo "should be in WS/edk2 dir"


## Clean up previous build files.
if [ -e $CORE_PATH/EDK2.log ]; then
  rm $CORE_PATH/EDK2.log
fi

if [ -e $CORE_PATH/Unitool.log ]; then
  rm $CORE_PATH/Unitool.log
fi

if [ -e $CORE_PATH/Conf/target.txt ]; then
  rm $CORE_PATH/Conf/target.txt
fi

if [ -e $CORE_PATH/Conf/BiosId.env ]; then
  rm $CORE_PATH/Conf/BiosId.env
fi

if [ -e $CORE_PATH/Conf/tools_def.txt ]; then
  echo "do not delete tools_def.txt"
  #rm $CORE_PATH/Conf/tools_def.txt
fi

if [ -e $CORE_PATH/Conf/build_rule.txt ]; then
  rm $(pwd)/Conf/build_rule.txt
fi


## Setup EDK environment. Edksetup puts new copies of target.txt, tools_def.txt, build_rule.txt in WorkSpace\Conf
## Also run edksetup as soon as possible to avoid it from changing environment variables we're overriding
. edksetup.sh BaseTools
make -C BaseTools

## Define platform specific environment variables.
PLATFORM_NAME=Vlv2TbltDevicePkg
PLATFORM_PACKAGE=$PLATFORM_PATH/Vlv2TbltDevicePkg
config_file=$PLATFORM_PACKAGE/PlatformPkgConfig.dsc
auto_config_inc=$PLATFORM_PACKAGE/AutoPlatformCFG.txt

## default ECP (override with /ECP flag)
EDK_SOURCE=$CORE_PATH/EdkCompatibilityPkg

## create new AutoPlatformCFG.txt file
if [ -f "$auto_config_inc" ]; then
  rm $auto_config_inc
fi
touch $auto_config_inc

##**********************************************************************
## Parse command line arguments
##**********************************************************************

PF=-n

## Optional arguments
for (( i=1; i<=$#; ))
  do
    if [ "$1" == "/?" ]; then
      Usage
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/Q" ]; then
      Build_Flags="$Build_Flags --quiet"
      QF="--quiet"
      shift
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/L" ]; then
          Build_Flags=$Build_Flags" -j EDK2.log "
          JLog="--log=EDK2.log"
          echo " /l for "$JLog
      shift
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/C" ]; then
      #echo Removing previous build files ...
      echo " /c for Clean Build Build dir=" $WORKSPACE/Build
      if [ -d "$WORKSPACE/Build" ]; then
      echo Removing previous build files ...
        rm -r $WORKSPACE/Build
      fi
      shift
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/ECP" ]; then
      ECP_SOURCE=$WORKSPACE/EdkCompatibilityPkgEcp
      EDK_SOURCE=$WORKSPACE/EdkCompatibilityPkgEcp
      echo DEFINE ECP_BUILD_ENABLE = TRUE >> $auto_config_inc
      shift
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/X64" ]; then
      Arch=X64
      shift

    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/P3" ]; then
      TN=3
      shift

    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/P5" ]; then
      TN=5
      shift
    elif [ "$(echo $1 | tr 'a-z' 'A-Z')" == "/YL" ]; then
      SpiLock=1
      shift      
    else
      break
    fi
  done





## Required argument(s)
if [ "$2" == "" ]; then
  Usage
fi

## Remove the values for Platform_Type and Build_Target from BiosIdX.env and stage in Conf
if [ $Arch == "IA32" ]; then
  cp $PLATFORM_PACKAGE/BiosId.env    Conf/BiosId.env
  echo DEFINE X64_CONFIG = FALSE      >> $auto_config_inc
else
  cp $PLATFORM_PACKAGE/BiosId.env  Conf/BiosId.env
  echo DEFINE X64_CONFIG = TRUE       >> $auto_config_inc
fi
sed -i '/^BOARD_ID/d' Conf/BiosId.env
sed -i '/^BUILD_TYPE/d' Conf/BiosId.env



## -- Build flags settings for each Platform --
##    AlpineValley (ALPV):  SVP_PF_BUILD = TRUE,   ENBDT_PF_BUILD = FALSE,  TABLET_PF_BUILD = FALSE,  BYTI_PF_BUILD = FALSE, IVI_PF_BUILD = FALSE
##       BayleyBay (BBAY):  SVP_PF_BUILD = FALSE,  ENBDT_PF_BUILD = TRUE,   TABLET_PF_BUILD = FALSE,  BYTI_PF_BUILD = FALSE, IVI_PF_BUILD = FALSE
##         BayLake (BLAK):  SVP_PF_BUILD = FALSE,  ENBDT_PF_BUILD = FALSE,  TABLET_PF_BUILD = TRUE,   BYTI_PF_BUILD = FALSE, IVI_PF_BUILD = FALSE
##      Bakersport (BYTI):  SVP_PF_BUILD = FALSE,  ENBDT_PF_BUILD = FALSE,  TABLET_PF_BUILD = FALSE,  BYTI_PF_BUILD = TRUE, IVI_PF_BUILD = FALSE
## Crestview Hills (CVHS):  SVP_PF_BUILD = FALSE,  ENBDT_PF_BUILD = FALSE,  TABLET_PF_BUILD = FALSE,  BYTI_PF_BUILD = TRUE, IVI_PF_BUILD = TRUE
##            FFD8 (BLAK):  SVP_PF_BUILD = FALSE,  ENBDT_PF_BUILD = FALSE,  TABLET_PF_BUILD = TRUE,   BYTI_PF_BUILD = FALSE, IVI_PF_BUILD = FALSE
echo "Setting  $1  platform configuration and BIOS ID..."
if [ "$(echo $1 | tr 'a-z' 'A-Z')" == "MNW2" ]; then
  echo BOARD_ID = MNW2MAX             >> Conf/BiosId.env
  echo DEFINE ENBDT_PF_BUILD = TRUE  >> $auto_config_inc
else
  echo "Error - Unsupported PlatformType: $1"
  Usage
fi

Platform_Type=$1

if [ "$(echo $2 | tr 'a-z' 'A-Z')" == "RELEASE" ]; then
  TARGET=RELEASE
  BUILD_TYPE=R
  SDB=SYMBOLIC_DEBUG=FALSE
  LG=LOGGING=FALSE
  echo BUILD_TYPE = R >> Conf/BiosId.env
else
  TARGET=DEBUG
  BUILD_TYPE=D
  SDB=SYMBOLIC_DEBUG=TRUE
  LG=LOGGING=TRUE
  echo BUILD_TYPE = D >> Conf/BiosId.env
fi


##**********************************************************************
## Additional EDK Build Setup/Configuration
##**********************************************************************
echo "Ensuring correct build directory is present for GenBiosId..."

echo Modifing Conf files for this build...
## Remove lines with these tags from target.txt
sed -i '/^ACTIVE_PLATFORM/d' Conf/target.txt
sed -i '/^TARGET /d' Conf/target.txt
sed -i '/^TARGET_ARCH/d' Conf/target.txt
sed -i '/^TOOL_CHAIN_TAG/d' Conf/target.txt
sed -i '/^MAX_CONCURRENT_THREAD_NUMBER/d' Conf/target.txt


ACTIVE_PLATFORM=$PLATFORM_PACKAGE/PlatformPkgGcc"$Arch".dsc
TOOL_CHAIN_TAG=GCC5
MAX_CONCURRENT_THREAD_NUMBER=$TN
echo ACTIVE_PLATFORM = $ACTIVE_PLATFORM                           >> Conf/target.txt
echo TARGET          = $TARGET                                    >> Conf/target.txt
echo TOOL_CHAIN_TAG  = $TOOL_CHAIN_TAG                            >> Conf/target.txt
echo MAX_CONCURRENT_THREAD_NUMBER = $MAX_CONCURRENT_THREAD_NUMBER >> Conf/target.txt
if [ $Arch == "IA32" ]; then
  echo TARGET_ARCH   = IA32                                       >> Conf/target.txt
else
  echo TARGET_ARCH   = IA32 X64                                   >> Conf/target.txt
fi

##**********************************************************************
## Build BIOS
##**********************************************************************
echo Skip "Running UniTool..."
echo "Make GenBiosId Tool..."
BUILD_PATH=Build/$PLATFORM_NAME/"$TARGET"_"$TOOL_CHAIN_TAG"
if [ ! -d "$WORKSPACE/$BUILD_PATH/$Arch" ]; then
  mkdir -p $WORKSPACE/$BUILD_PATH/$Arch
fi
if [ -e "$WORKSPACE/$BUILD_PATH/$Arch/BiosId.bin" ]; then
  rm -f $WORKSPACE/$BUILD_PATH/$Arch/BiosId.bin
fi


$PLATFORM_PACKAGE/GenBiosId -i $CORE_PATH/Conf/BiosId.env -o $WORKSPACE/$BUILD_PATH/$Arch/BiosId.bin

 ##**********************************************************************
 ##  Invoke the EDK2 BUILD HERE
 ##**********************************************************************
 cat Conf/target.txt
 echo  Check the above target.txt for correct platform
 echo . . . 
 echo Current directory is $(pwd)
 echo . . . 
 echo  
 echo "Invoking EDK2 build..."
 echo "build " $JLog  -D $SDB -D $LG $QF 
 echo "Press ENTER to continue OR Control-C to abort"
 read
 echo build  $JLog  -D $SDB -D $LG $QF  
 build  $JLog  -D $SDB -D $LG $QF 
 echo command for build  $JLog -D $SDB -D $LG $QF


if [ $SpiLock == "1" ]; then
  IFWI_HEADER_FILE=$PLATFORM_PACKAGE/Stitch/IFWIHeader/IFWI_HEADER_SPILOCK.bin
else
  IFWI_HEADER_FILE=$PLATFORM_PACKAGE/Stitch/IFWIHeader/IFWI_HEADER.bin
fi

echo $IFWI_HEADER_FILE

##**********************************************************************
## Post Build processing and cleanup
##**********************************************************************

echo Skip "Running fce..."

echo Skip "Running KeyEnroll..."

## Set the Board_Id, Build_Type, Version_Major, and Version_Minor environment variables
VERSION_MAJOR=$(grep '^VERSION_MAJOR' Conf/BiosId.env | cut -d ' ' -f 3 | cut -c 1-4)
VERSION_MINOR=$(grep '^VERSION_MINOR' Conf/BiosId.env | cut -d ' ' -f 3 | cut -c 1-2)
BOARD_ID=$(grep '^BOARD_ID' Conf/BiosId.env | cut -d ' ' -f 3 | cut -c 1-7)
BIOS_Name="$BOARD_ID"_"$Arch"_"$BUILD_TYPE"_"$VERSION_MAJOR"_"$VERSION_MINOR".ROM
BIOS_ID="$BOARD_ID"_"$Arch"_"$BUILD_TYPE"_"$VERSION_MAJOR"_"$VERSION_MINOR"_GCC.bin
cp -f $WORKSPACE/$BUILD_PATH/FV/VLV.fd  $WORKSPACE/$BIOS_Name

echo > $WORKSPACE/$BUILD_PATH/FV/SYSTEMFIRMWAREUPDATECARGO.Fv
build -p $PLATFORM_PACKAGE/PlatformCapsuleGcc.dsc
SEC_VERSION=1.0.2.1060v5
cat $IFWI_HEADER_FILE $SILICON_PATH/Vlv2MiscBinariesPkg/SEC/$SEC_VERSION/VLV_SEC_REGION.bin $SILICON_PATH/Vlv2MiscBinariesPkg/SEC/$SEC_VERSION/Vacant.bin $WORKSPACE/$BIOS_Name > $PLATFORM_PACKAGE/Stitch/$BIOS_ID


echo Skip "Running BIOS_Signing ..."

echo
echo Build location:     $BUILD_PATH
echo BIOS ROM Created:   $BIOS_Name
echo
echo -------------------- The EDKII BIOS build has successfully completed. --------------------
echo
