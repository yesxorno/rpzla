#!/bin/bash

CONF=/etc/rpzla/rpzla.conf
RETVAL=1
ME=`basename $0`
DIR=`dirname $0`
if [ -r "$CONF" ]
then
	echo "Can't read '$CONF'" >&2
	exit 1
elif $DIR/create_structures.pl && ( cd $DIR/sample-data && ./upload.pl )
then
	echo "Created database and uploaded sample data." >&2
	RETVAL=0
else
	echo "Failure creating database and/or uploading sample data" >&2
fi

exit $RETVAL
