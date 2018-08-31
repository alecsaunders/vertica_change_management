#!/bin/bash

while getopts "hd:t:x" opt; do
  case ${opt} in
    h)
      echo "Deploy Table:"
      echo "============="
      echo "Usage:";
      echo -e "-d\tDatabase to deploy/rollback changes to"
      echo -e "\t\tOptions are: "
      echo -e "-t\tPath to table to deploy: i.e. _SCHEMAS_/<schema>/_TABLES_/<table_name>"
      exit 0;
      ;;
    d)
      TARGET_DATABASE=$OPTARG
      ;;
    t)
      TABLENAME=$OPTARG
      ;;
    x)
      EXCLUDE_SCHEMA_CREATION=1
      ;;
    *)
      echo "Unknown Option"
      exit 1
      ;;
  esac
done

####
# Source DB Connection Variables
####
. "$TOPDIR"/confs/db_"$TARGET_DATABASE".cfg

TOPDIR=$(pwd)
DIR=$TABLENAME
cd $DIR

if [[ $EXCLUDE_SCHEMA_CREATION -ne 1 ]]; then
  CREATESCHEMA=`cat ../../CREATE_SCHEMA.sql`

  EXITCODE=0
  echo "$CREATESCHEMA" \
    | vsql -U $user -d $database -h $host -v ON_ERROR_STOP=on
  EXITCODE=$[$EXITCODE+$?]

  if [[ $EXITCODE -gt 0 ]]; then
    cd $TOPDIR
    echo $(date) "- ERROR - Error creating schema:" "$SCHEMANAME" >> "$TOPDIR"/deploy.log
    exit $EXITCODE
  fi

  CREATESEQUENCE=`cat ../../CREATE_SEQUENCE.sql`
  echo "$CREATESEQUENCE" \
    | vsql -U $user -d $database -h $host -X -v ON_ERROR_STOP=off >> "$TOPDIR"/deploy.log 2>&1
fi

SCHEMANAME=$(basename "$(dirname "$(dirname "$DIR")")")
TABLENAME=$(basename "$DIR")
CREATETABLE=$(<CREATE_TABLE.sql)
ALTERTABLE=$(<ALTER_TABLE.sql)
CREATEPROJECTION=`cat _PROJECTIONS_/CREATE_PROJECTION.sql`
REFRESH="SELECT REFRESH('"$SCHEMANAME"."$TABLENAME"');"
DROPPROJECTION=`cat _PROJECTIONS_/DROP_PROJECTION.sql`

EXITCODE=0
echo $(date) "- INFO - Beginning work on table:" "$SCHEMANAME"."$TABLENAME" >> "$TOPDIR"/deploy.log
echo "$CREATETABLE" "$ALTERTABLE" \
| vsql -U $user -d $database -h $host -v ON_ERROR_STOP=off

echo "$CREATEPROJECTION" "$REFRESH" "SELECT MAKE_AHM_NOW();" "$DROPPROJECTION" \
  | vsql -U $user -d $database -h $host -v ON_ERROR_STOP=on
EXITCODE=$[$EXITCODE+$?]

cd $TOPDIR
if [[ $EXITCODE -gt 0 ]]; then
  echo $(date) "- ERROR -" "$SCHEMANAME"."$TABLENAME" >> "$TOPDIR"/deploy.log
  exit $EXITCODE
else
  echo $(date) "- INFO - Success Deploying:" "$SCHEMANAME"."$TABLENAME" >> "$TOPDIR"/deploy.log
fi
