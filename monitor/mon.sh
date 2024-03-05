#!/bin/sh
WORK_DIR=/monitor
DATA_FILE=/var/log/syslog
LOG_PATH=$WORK_DIR/log
LOG_FILE=$LOG_PATH/monitor.`date +%Y%m%d`.log
LINE_NO_FILE=$WORK_DIR/messages.trace
INODE_FILE=$WORK_DIR/messages.inode
PATTERN_FILE=$WORK_DIR/mon_system.dat
IGNORE_PATTERN=$WORK_DIR/mon_ignore.dat
TEMP_FILE1=/tmp/mon_sys.tmp1
TEMP_FILE2=/tmp/mon_sys.tmp2
RESULT_FILE=/tmp/mon_sys.result
#OPCMSG=/macro/monitor/opcmsg.sh
MAIL_FILE=/tmp/mon_sys.mail
HOSTNAME=`uname -n`
MAILING_LIST=song.zhang@westwell-lab.com
SERVER_URL="http://10.6.64.42:8888/send_mail"

##############################
STARTUP()
{
# check message file exists or not
if [ ! -f $DATA_FILE ]
then    echo "$DATA_FILE doesn't exist. Please check then try again."
        exit 0
fi
# check pattern file exists or not
if [ ! -f $PATTERN_FILE ]
then    echo "$PATTERN_FILE doesn't exist. Please create then try again."
        exit 0
fi
# check history files exist or not, if not, reset both of them.
if [ ! -f $LINE_NO_FILE -o ! -f $INODE_FILE ]
then    echo "Some history files missing, may be the first time to run. "
        echo "Reset the history files."
        echo "0" > $LINE_NO_FILE
        echo "0" > $INODE_FILE
fi
}

##############################
CHECKCHANGES()
{
if [ $INODE1 -eq $INODE2 ]
then    if [ $LINE_NO_1 -eq $LINE_NO_2 ]
        then    echo "$DATA_FILE has no change."
                exit 0
        else    echo "$DATA_FILE has been updated since last run."
        fi
else    echo "$DATA_FILE was switched, reset line number to 0."
        echo "0" > $LINE_NO_FILE
fi
}

##############################
GET_TEMP_FILE1()
{
if [ $LINE_NEW -gt 0 ]
then
tail -$LINE_NEW $DATA_FILE > $TEMP_FILE1
fi
}

##############################
GEN_MESSAGE()
{
  if [ -f $IGNORE_PATTERN ]; then
    egrep -if $PATTERN_FILE $TEMP_FILE1 | egrep -ivf $IGNORE_PATTERN > $TEMP_FILE2
  else
    egrep -if $PATTERN_FILE $TEMP_FILE1 > $TEMP_FILE2
  fi

  awk '{printf $0 " "; printf "\n"}' $TEMP_FILE2 > $RESULT_FILE
}

##############################
GEN_EMAIL()
{
if [ -s $RESULT_FILE ]
then
  while read F1 F2
  do
    OPCMESSAGE=`echo $F2 |sed s/\ /_/g |sed s/\(/\[/g |sed s/\)/\]/g `
    echo $OPCMESSAGE >> $MAIL_FILE
  done < $RESULT_FILE

  #mailx -s "System Warning on ${HOSTNAME}" $MAILING_LIST < $MAIL_FILE
  curl -X POST -H "Content-Type: application/json" -d '{"file_path":"'''$MAIL_FILE'''"}' $SERVER_URL
fi
}

##############################
UPDATE_STATUS()
{
echo $LINE_NO_2 > $LINE_NO_FILE
echo $INODE2 > $INODE_FILE
}

##############################
CLEAR_TEMPFILE()
{
/usr/bin/rm -f $TEMP_FILE1
/usr/bin/rm -f $TEMP_FILE2
/usr/bin/rm -f $RESULT_FILE
/usr/bin/rm -f $MAIL_FILE
}

##############################
MAIN()
{
date
STARTUP
LINE_NO_1=`cat $LINE_NO_FILE`
LINE_NO_2=`cat $DATA_FILE |wc -l`
LINE_NEW=`expr $LINE_NO_2 - $LINE_NO_1`
INODE1=`cat $INODE_FILE`
INODE2=`ls -i $DATA_FILE |awk '{print $1 }'`
#
CHECKCHANGES
GET_TEMP_FILE1
GEN_MESSAGE
GEN_EMAIL
UPDATE_STATUS
CLEAR_TEMPFILE
}

##############################
# Check Log path exists or not
if [ ! -d $LOG_PATH ]
then mkdir $LOG_PATH
fi
MAIN |tee -a $LOG_FILE

cd $LOG_PATH
find . -name "monitor.*.log" -mtime +7 -exec rm {} \;


