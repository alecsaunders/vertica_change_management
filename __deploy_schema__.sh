#!/bin/bash

DB_LIST=""
SCHEMALIST=`ls _SCHEMAS_`

while getopts "hd:s:" opt; do
  case ${opt} in
    h)
      echo "Usage:";
      echo -e "-d\tDatabase to deploy/rollback changes to"
      echo -e "\t\tOptions are: "
      echo -e "-s\tSchema to deploy"
      echo -e "\t\tOptions are:" $SCHEMALIST
      exit 0;
      ;;
    d)
      TARGET_DATABASE=$OPTARG
      ;;
    s)
      SCHEMANAME=$OPTARG
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
    exit 1
  fi
fi

####
# Source DB Connection Variables
####
. "$TOPDIR"/confs/db_"$TARGET_DATABASE".cfg

if [ -z $SCHEMANAME ]; then
  echo "Must specify schema name using '-s'."
  echo -e "\tOptions are: ["$SCHEMALIST"]"
  exit 1
else
  MATCH=0
  for s in $SCHEMALIST; do
    if [ $s == $SCHEMANAME ]; then
      MATCH=1
    fi
  done
  if [[ MATCH -eq 0 ]]; then
    echo "Schema name \"$SCHEMANAME\" is invalid:"
    echo -e "\tOptions are: ["$SCHEMALIST"]"
    exit 1
  fi
fi

CREATESCHEMA=`cat _SCHEMAS_/"$SCHEMANAME"/CREATE_SCHEMA.sql`
CREATESEQUENCE=`cat _SCHEMAS_/"$SCHEMANAME"/CREATE_SEQUENCE.sql`

echo $(date) "- INFO - Starting work on schema:" $SCHEMANAME >> deploy.log

echo "$CREATESCHEMA" \
  | vsql -U $user -d $database -h $host -X -v ON_ERROR_STOP=off >> deploy.log 2>&1
echo "$CREATESEQUENCE" \
  | vsql -U $user -d $database -h $host -X -v ON_ERROR_STOP=off >> deploy.log 2>&1

for t in _SCHEMAS_/"$SCHEMANAME"/_TABLES_/*; do
  bash $(PWD)/__deploy_table__.sh -d $TARGET_DATABASE -t $t -x
done

echo $(date) "- INFO - Ending work on schema:" $SCHEMANAME >> deploy.log
