#!/bin/bash

TOPDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $TOPDIR

DB_LIST=""
SCHEMALIST=`ls _SCHEMAS_`

####
# OPTION PARSING
####
while getopts "d:s:t:h" opt; do
  case ${opt} in
    d)
      TARGET_DATABASE=$OPTARG
      ;;
    s)
      SCHEMANAME=$OPTARG
      ;;
    t)
      TABLENAME=$OPTARG
      ;;
    h)
      echo "Rollback Table:"
      echo "============="
      echo "Usage:";
      echo -e "-d\tDatabase to deploy/rollback changes to"
      echo -e "\t\tOptions are: $DB_LIST"
      echo -e "-s\tSchema of table to rollback"
      if [[ $SCHEMANAME ]]; then
        echo -e "\t\tSelected schema:" $SCHEMANAME
      else
        echo -e "\t\tOptions are:" $SCHEMALIST
      fi
      echo -e "-t\tTable to rollback"
      if [[ $SCHEMANAME ]]; then
        TABLELIST=`ls _SCHEMAS_/"$SCHEMANAME"/_TABLES_`
        echo -e "\t\tOptions are:" $TABLELIST
      fi
      echo ""
      echo "Note: To see a list of tables, include the schema using the -s option and then use -h."
      exit 0;
      ;;
    *)
      echo "Unknown Option"
      exit 1
      ;;
  esac
done

if [ -z $TARGET_DATABASE ]; then
  echo "ERROR: Target database not set. Use -d option to specify database."
  echo -e "\t\tOptions are: $DB_LIST"
  exit 1
fi

if [ -z $SCHEMANAME ]; then
  echo "ERROR: Table schema not set. Use -s option to specify schema."
  echo -e "\t\tOptions are:" $SCHEMALIST
  exit 1
fi

if [ -z $TABLENAME ]; then
  echo "ERROR: Table not set. Use -t option to specify table."
  if [[ $SCHEMANAME ]]; then
    TABLELIST=`ls _SCHEMAS_/"$SCHEMANAME"/_TABLES_`
    echo -e "\t\tOptions for schema \"$SCHEMANAME\" are:" $TABLELIST
  fi
  exit 1
fi

####
# Source DB Connection Variables
####
. "$TOPDIR"/confs/db_"$TARGET_DATABASE".cfg


####
# Execute Script Logic
####
DIR="_SCHEMAS_/"$SCHEMANAME"/_TABLES_/"$TABLENAME
ROLLBACK=$(<"$DIR"/ROLLBACK.sql)

EXITCODE=0
echo $ROLLBACK \
  | vsql -U $user -d $database -h $host -v ON_ERROR_STOP=on
EXITCODE=$[$EXITCODE+$?]

# Log results
if [[ $EXITCODE -gt 0 ]]; then
  echo $(date) "- ERROR - Error Rolling back" "$SCHEMANAME"."$TABLENAME" >> deploy.log
  exit $EXITCODE
else
  echo $(date) "- INFO - Success Rolling back:" "$SCHEMANAME"."$TABLENAME" >> deploy.log
fi
