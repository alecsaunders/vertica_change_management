#!/bin/bash
DIR=$1

for d in "$DIR"_TABLES_/*; do
  bash $(PWD)/__rollback_table__.sh $d
done
