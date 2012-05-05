#!/bin/bash

CONF=/etc/rpzla/rpzla.conf
RETVAL=1
ME=`basename $0`
DIR=`dirname $0`
if [ ! -r "$CONF" ]
then
	echo "Can't read '$CONF'" >&2
elif $DIR/create_structures.pl && ( cd $DIR/sample-data && ./upload.pl )
then
	echo "Completed creating database, schema, roles, tables, views" >&2
	echo "and uploading sample data." >&2
	RETVAL=0
else
	echo "Failure during creating database/schema/roles/tables/users" >&2
	echo "or uploading sample data." >&2
fi

exit $RETVAL
