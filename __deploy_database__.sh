#!/bin/bash

DB_LIST=""

while getopts "hd:" opt; do
  case ${opt} in
    h)
      echo "Usage:";
      echo -e "-d\tDatabase to deploy/rollback changes to"
      echo -e "\t\tOptions are: "
      exit 0;
      ;;
    d)
      TARGET_DATABASE=$OPTARG
      ;;
    *)
      echo "Unknown Option"
      exit 1
      ;;
  esac
done

if [ -z $TARGET_DATABASE ]; then
  echo "Must specify target databse using '-d'."
  echo -e "\tOptions are: "
  exit 1
else
  MATCH=0
  for DB in $DB_LIST; do
    if [ $DB == $TARGET_DATABASE ]; then
      MATCH=1
    fi
  done
  if [[ MATCH -eq 0 ]]; then
    echo "Database value \"$TARGET_DATABASE\" is invalid:"
    echo -e "\tOptions are: "
  fi
fi

EXITCODE=0

####
# Source DB Connection Variables
####
. "$TOPDIR"/confs/db_"$TARGET_DATABASE".cfg

# SET DATABASE CONFIGURATION PARAMETERS
SETCONFIGPARAMETERS=$(<_CONFIGURATION_PARAMETERS_/SET_CONFIGURATION_PARAMETERS.sql)
echo "$SETCONFIGPARAMETERS" | vsql -U $user -d $database -h $host -v ON_ERROR_STOP=on
EXITCODE=$[$EXITCODE+$?]

if [[ $EXITCODE -gt 0 ]]; then
  echo $(date) "- ERROR - Setting database configuration parameters" >> deploy.log
  exit $EXITCODE
fi

SCHEMALIST=`ls _SCHEMAS_`
for s in $SCHEMALIST; do
  ./__deploy_schema__.sh -d $TARGET_DATABASE -s $s
done
