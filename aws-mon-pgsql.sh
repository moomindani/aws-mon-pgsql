#!/bin/bash

# Copyright (C) 2014 mooapp
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not 
# use this file except in compliance with the License. A copy of the License 
# is located at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "LICENSE" file accompanying this file. This file is distributed 
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
# express or implied. See the License for the specific language governing 
# permissions and limitations under the License.


########################################
# Initial Settings
########################################
SCRIPT_NAME=${0##*/} 
SCRIPT_VERSION=1.0 

export AWS_CLOUDWATCH_HOME=/opt/aws/apitools/mon
instanceid=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`
azone=`wget -q -O - http://169.254.169.254/latest/meta-data/placement/availability-zone`
region=${azone/%?/}
export EC2_REGION=$region



########################################
# Usage
########################################
usage() 
{ 
    echo "Usage: $SCRIPT_NAME [options] "
    echo "Options:" 
    echo -e "\t--help\tDisplays detailed usage information."
    echo -e "\t--version\tDisplays the version number."
    echo -e "\t--verify\tChecks configuration and prepares a remote call."
    echo -e "\t--verbose\tDisplays details of what the script is doing."
    echo -e "\t--debug\tDisplays information for debugging."
    echo -e "\t--from-cron\tUse this option when calling the script from cron."
    echo -e "\t--aws-credential-file PATH\tProvides the location of the file containing AWS credentials. This parameter cannot be used with the --aws-access-key-id and --aws-secret-key parameters."
    echo -e "\t--aws-access-key-id VALUE\tSpecifies the AWS access key ID to use to identify the caller. Must be used together with the --aws-secret-key option. Do not use this option with the --aws-credential-file parameter."
    echo -e "\t--aws-secret-key VALUE\tSpecifies the AWS secret access key to use to sign the request to CloudWatch. Must be used together with the --aws-access-key-id option. Do not use this option with --aws-credential-file parameter."
    echo -e "\t--id\tSpecifies database instance identifier."
    echo -e "\t-h\tSpecifies database server host."
    echo -e "\t-p\tSpecifies database server port."
    echo -e "\t-U\tSpecifies database user."
    echo -e "\t-d\tSpecifies database name."
    echo -e "\t--status\tReports the status."
    echo -e "\t--timeut\tSpecifies status check timeout."
    echo -e "\t--session-active\tReports the number of sessions whose status is active."
    echo -e "\t--session-idle\tReports the number of sessions whose status is idle."
    echo -e "\t--session-wait\tReports the number of sessions whose status is wait."
    echo -e "\t--cache-hit\tReports cache hit ratio."
    echo -e "\t--tup-inserted\tReports the number of tupples inserted."
    echo -e "\t--tup-updated\tReports the number of tupples updated."
    echo -e "\t--tup-deleted\tReports the number of tupples deleted."
    echo -e "\t--tup-returned\tReports the number of tupples returned."
    echo -e "\t--tup-fetched\tReports the number of tupples fetched."
    echo -e "\t--buffers-checkpoint\tReports the number of buffers written for checkpoint."
    echo -e "\t--buffers-clean\tReports the number of buffers written for cleaning."
    echo -e "\t--buffers-backend\tReports the number of buffers written for backend."
    echo -e "\t--blks-read\tReports the number of blocks not included in shared memory and read from disk."
    echo -e "\t--blks-hit\tReports the number of blocks included in shared memory."
    echo -e "\t--txn-commit\tReports the number of transactions committed."
    echo -e "\t--txn-rollback\tReports the number of transactions rollbacked."
    echo -e "\t--locks-acquired\tReports the number of locks acquired."
    echo -e "\t--locks-wait\tReports the number of locks wait."
    echo -e "\t--all-items\tReports all items."
}


########################################
# Options
########################################
SHORT_OPTS="h:,p:,U:,d:"
LONG_OPTS="help,version,verify,verbose,debug,from-cron,aws-credential-file:,aws-access-key-id:,aws-secret-key:,id:,status,timeout:,session-active,session-idle,session-wait,cache-hit,tup-inserted,tup-updated,tup-deleted,tup-returned,tup-fetched,buffers-checkpoint,buffers-clean,buffers-backend,blks-read,blks-hit,txn-commit,txn-rollback,locks-acquired,locks-wait,all-items"

ARGS=$(getopt -s bash --options $SHORT_OPTS --longoptions $LONG_OPTS --name $SCRIPT_NAME -- "$@" ) 

VERIFY=0
VERBOSE=0
DEBUG=0
FROM_CRON=0
AWS_CREDENTIAL_FILE=""
AWS_ACCESS_KEY_ID=""
AWS_SECRET_KEY=""

PGHOST="localhost"
PGPORT=5432
PGUSER="postgres"
DBNAME="postgres"

STATUS=0
SESSION_ACTIVE=0
SESSION_IDLE=0
SESSION_WAIT=0
CACHE_HIT=0
TUP_INSERTED=0
TUP_UPDATED=0
TUP_DELETED=0
TUP_RETURNED=0
TUP_FETCHED=0
BUFFERS_CHECKPOINT=0
BUFFERS_CLEAN=0
BUFFERS_BACKEND=0
BLKS_READ=0
BLKS_HIT=0
TXN_COMMIT=0
TXN_ROLLBACK=0
LOCKS_ACQUIRED=0
LOCKS_WAIT=0

CACHE_FILE="/var/tmp/aws-mon-pgsql.cache"
cache_buffer="# cache file for aws-mon-pgsql"

eval set -- "$ARGS" 
while true; do 
    case $1 in 
        # General
        --help) 
            usage 
            exit 0 
            ;; 
        --version) 
            echo "$SCRIPT_VERSION" 
            ;;
        --verify)
            VERIFY=1  
            ;; 
        --verbose)
            VERBOSE=1   
            ;;
        --debug)
            DEBUG=1
            ;;
        --from-cron)
            FROM_CRON=1
            ;;
        # Credential
        --aws-credential-file)
            shift
            AWS_CREDENTIAL_FILE=$1
            ;;
        --aws-access-key-id)
            shift
            AWS_ACCESS_KEY_ID=$1
            ;;
        --aws-secret-key)
            shift
            AWS_SECRET_KEY=$1
            ;;
        # DB instance identifier
        --id)
            shift
            DB_INSTANCE_IDENTIFIER=$1
            ;;
        # Psql Options
        -h)
            shift
            PGHOST=$1
            ;;
        -p)
            shift
            PGPORT=$1
            ;;
        -U)
            shift
            PGUSER=$1
            ;;
        -d)
            shift
            DBNAME=$1
            ;;
        # Status
        --status)
            STATUS=1
            ;;
        --timeout)
            shift
            STATUS_CHECK_TIMEOUT=$1
            ;;
        # Session
        --session-active)
            SESSION_ACTIVE=1
            ;;
        --session-idle)
            SESSION_IDLE=1
            ;;
        --session-wait)
            SESSION_WAIT=1
            ;;
        # Cache hit
        --cache-hit)
            CACHE_HIT=1
            ;;
        # Tupples
        --tup-inserted)
            TUP_INSERTED=1
            ;;
        --tup-updated)
            TUP_UPDATED=1
            ;;
        --tup-deleted)
            TUP_DELETED=1
            ;;
        --tup-returned)
            TUP_RETURNED=1
            ;;
        --tup-fetched)
            TUP_FETCHED=1
            ;;
        # Buffers
        --buffers-checkpoint)
            BUFFERS_CHECKPOINT=1
            ;;
        --buffers-clean)
            BUFFERS_CLEAN=1
            ;;
        --buffers-backend)
            BUFFERS_BACKEND=1
            ;;
        # Blocks
        --blks-read)
            BLKS_READ=1
            ;;
         --blks-hit)
            BLKS_HIT=1
            ;;
        # Transactions
        --txn-commit)
            TXN_COMMIT=1
            ;;
        --txn-rollback)
            TXN_ROLLBACK=1
            ;;
        # Locks
        --locks-acquired)
            LOCKS_ACQUIRED=1
            ;;
        --locks-wait)
            LOCKS_WAIT=1
            ;;
        # All items
        --all-items)
            STATUS=1
            SESSION_ACTIVE=1
            SESSION_IDLE=1
            SESSION_WAIT=1
            CACHE_HIT=1
            TUP_INSERTED=1
            TUP_UPDATED=1
            TUP_DELETED=1
            TUP_RETURNED=1
            TUP_FETCHED=1
            BUFFERS_CHECKPOINT=1
            BUFFERS_CLEAN=1
            BUFFERS_BACKEND=1
            BLKS_READ=1
            TXN_COMMIT=1
            TXN_ROLLBACK=1
            LOCKS_ACQUIRED=1
            LOCKS_WAIT=1
            ;;
        --) 
            shift
            break 
            ;; 
        *) 
            shift
            break 
            ;; 
    esac 
    shift 
done


########################################
# psql Command
########################################
PSQL_CMD="/usr/bin/psql -h $PGHOST -p $PGPORT -U $PGUSER -d $DBNAME -A -t -c"


########################################
# Utility Function
########################################

# get value from previous result
# Input format: 
#     $1 : key
#     $2 : default value
function getCache()
{
    if [ -f $CACHE_FILE ]; then
	RET=`sed '/^¥#/d' $CACHE_FILE | grep "^${1}"  | tail -n 1 | sed -e 's/^.*=//'`
    fi
    
    if [ -z "$RET" ]; then
        RET=$2
    fi

    echo $RET
}

# set value into cache 
# (this function writes temporary buffer and does not write cache file yet)
#
# Input format: 
#     $1 : key
#     $2 : value
function setCache()
{
    cache_buffer="$cache_buffer\\n$1=$2"
}

# write cache file using temporary buffer
function writeCache()
{
    echo -e "$cache_buffer" > $CACHE_FILE
}


########################################
# Main
########################################

# Avoid a storm of calls at the beginning of a minute
if [ $FROM_CRON -eq 1 ]; then
    sleep $(((RANDOM%20) + 1))
fi

# CloudWatch Command Line Interface Option
CLOUDWATCH_OPTS="--namespace \"aws-mon-pgsql\" --dimensions \"DBInstanceIdentifier=$DB_INSTANCE_IDENTIFIER\""
if [ -n "$AWS_CREDENTIAL_FILE" ]; then
    CLOUDWATCH_OPTS="$CLOUDWATCH_OPTS --aws-credential-file $AWS_CREDENTIAL_FILE"
elif [ -n "$AWS_ACCESS_KEY_ID" -a -n "$AWS_SECRET_KEY" ]; then
    CLOUDWATCH_OPTS="$CLOUDWATCH_OPTS --access-key-id $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_KEY"
fi

# Updating time
curr_time=`date +%s`
setCache "time" $curr_time
prev_time=`getCache "time" -1`
if [ $prev_time -eq -1 ]; then
    echo "Initial execution. "
    writeCache
    exit 0
fi
time_interval=`expr $curr_time - $prev_time`
if [ $VERBOSE -eq 1 ]; then
    echo "curr_time:$curr_time"
    echo "prev_time:$prev_time"
    echo "time_interval:$time_interval"
fi


# Status
if [ $STATUS -eq 1 ]; then
    query="SELECT 1 for UPDATE"
    env PGCONNECT_TIMEOUT=$STATUS_CHECK_TIMEOUT $PSQL_CMD "$query"
    pg_status=$?
    if [ $VERBOSE -eq 1 ]; then
        echo "pg_status:$pg_status"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "PgStatus" --value "$pg_status" --unit "Count" $CLOUDWATCH_OPTS
    fi

    if [ $pg_status -ne 0 ]; then
        echo "Aborted. error code : $pg_status"
        exit 1
    fi
fi

# Session
if [ $SESSION_ACTIVE -eq 1 ]; then
    query="SELECT count(*) FROM pg_stat_activity WHERE waiting='f' AND query NOT LIKE '<IDLE%' AND datname='$DBNAME'"
    session_active=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "session_active:$session_active"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "SessionActive" --value "$session_active" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $SESSION_IDLE -eq 1 ]; then
    query="SELECT count(*) FROM pg_stat_activity WHERE waiting='f' AND query LIKE '<IDLE%' AND datname='$DBNAME'"
    session_idle=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "session_idle:$session_idle"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "SessionIdle" --value "$session_idle" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $SESSION_WAIT -eq 1 ]; then
    query="SELECT count(*) FROM pg_stat_activity WHERE waiting='t' AND datname='$DBNAME'"
    session_wait=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "session_wait:$session_wait"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "SessionWait" --value "$session_wait" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Cache
if [ $CACHE_HIT -eq 1 ]; then
    query="SELECT round(blks_hit*100/(blks_hit+blks_read), 3) FROM pg_stat_database WHERE blks_read > 0 AND datname='$DBNAME'"
    cache_hit=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "cache_hit:$cache_hit"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "CacheHit" --value "$cache_hit" --unit "Percent" $CLOUDWATCH_OPTS
    fi
fi

# Transactions
if [ $TXN_COMMIT -eq 1 ]; then
    query="SELECT xact_commit FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_txn_commit=`$PSQL_CMD "$query"`
    prev_txn_commit=`getCache "txn_commit" $curr_txn_commit`
    raw_txn_commit=`expr $curr_txn_commit - $prev_txn_commit`
    txn_commit=`expr $raw_txn_commit / $time_interval`
    setCache "txn_commit" $curr_txn_commit
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_txn_commit:$curr_txn_commit"
        echo "prev_txn_commit:$prev_txn_commit"
        echo "raw_txn_commit:$raw_txn_commit"
        echo "txn_commit:$txn_commit"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TxnCommit" --value "$txn_commit" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $TXN_ROLLBACK -eq 1 ]; then
    query="SELECT xact_rollback FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_txn_rollback=`$PSQL_CMD "$query"`
    prev_txn_rollback=`getCache "txn_rollback" $curr_txn_rollback`
    raw_txn_rollback=`expr $curr_txn_rollback - $prev_txn_rollback`
    txn_rollback=`expr $raw_txn_rollback / $time_interval`
    setCache "txn_rollback" $curr_txn_rollback
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_txn_rollback:$curr_txn_rollback"
        echo "prev_txn_rollback:$prev_txn_rollback"
        echo "raw_txn_rollback:$raw_txn_rollback"
        echo "txn_rollback:$txn_rollback"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TxnRollback" --value "$txn_rollback" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Tupples
if [ $TUP_RETURNED -eq 1 ]; then
    query="SELECT sum(tup_returned) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_tup_returned=`$PSQL_CMD "$query"`
    prev_tup_returned=`getCache "tup_returned" $curr_tup_returned`
    raw_tup_returned=`expr $curr_tup_returned - $prev_tup_returned`
    tup_returned=`expr $raw_tup_returned / $time_interval`
    setCache "tup_returned" $curr_tup_returned
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_tup_returned:$curr_tup_returned"
        echo "prev_tup_returned:$prev_tup_returned"
        echo "raw_tup_returned:$raw_tup_returned"
        echo "tup_returned:$tup_returned"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TupReturned" --value "$tup_returned" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $TUP_FETCHED -eq 1 ]; then
    query="SELECT sum(tup_fetched) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_tup_fetched=`$PSQL_CMD "$query"`
    prev_tup_fetched=`getCache "tup_fetched" $curr_tup_fetched`
    raw_tup_fetched=`expr $curr_tup_fetched - $prev_tup_fetched`
    tup_fetched=`expr $raw_tup_fetched / $time_interval`
    setCache "tup_fetched" $curr_tup_fetched
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_tup_fetched:$curr_tup_fetched"
        echo "prev_tup_fetched:$prev_tup_fetched"
        echo "raw_tup_fetched:$raw_tup_fetched"
        echo "tup_fetched:$tup_fetched"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TupFetched" --value "$tup_fetched" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $TUP_INSERTED -eq 1 ]; then
    query="SELECT sum(tup_inserted) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_tup_inserted=`$PSQL_CMD "$query"`
    prev_tup_inserted=`getCache "tup_inserted" $curr_tup_inserted`
    raw_tup_inserted=`expr $curr_tup_inserted - $prev_tup_inserted`
    tup_inserted=`expr $raw_tup_inserted / $time_interval`
    setCache "tup_inserted" $curr_tup_inserted
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_tup_inserted:$curr_tup_inserted"
        echo "prev_tup_inserted:$prev_tup_inserted"
        echo "raw_tup_inserted:$raw_tup_inserted"
        echo "tup_inserted:$tup_inserted"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TupInserted" --value "$tup_inserted" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $TUP_UPDATED -eq 1 ]; then
    query="SELECT sum(tup_updated) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_tup_updated=`$PSQL_CMD "$query"`
    prev_tup_updated=`getCache "tup_updated" $curr_tup_updated`
    raw_tup_updated=`expr $curr_tup_updated - $prev_tup_updated`
    tup_updated=`expr $raw_tup_updated / $time_interval`
    setCache "tup_updated" $curr_tup_updated
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_tup_updated:$curr_tup_updated"
        echo "prev_tup_updated:$prev_tup_updated"
        echo "raw_tup_updated:$raw_tup_updated"
        echo "tup_updated:$tup_updated"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TupUpdated" --value "$tup_updated" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $TUP_DELETED -eq 1 ]; then
    query="SELECT sum(tup_deleted) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_tup_deleted=`$PSQL_CMD "$query"`
    prev_tup_deleted=`getCache "tup_deleted" $curr_tup_deleted`
    raw_tup_deleted=`expr $curr_tup_deleted - $prev_tup_deleted`
    tup_deleted=`expr $raw_tup_deleted / $time_interval`
    setCache "tup_deleted" $curr_tup_deleted
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_tup_deleted:$curr_tup_deleted"
        echo "prev_tup_deleted:$prev_tup_deleted"
        echo "raw_tup_deleted:$raw_tup_deleted"
        echo "tup_deleted:$tup_deleted"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "TupDeleted" --value "$tup_deleted" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Locks
if [ $LOCKS_ACQUIRED -eq 1 ]; then
    query="SELECT count(*) FROM pg_locks WHERE granted=true"
    locks_acquired=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "locks_acquired:$locks_acquired"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "LocksAcquired" --value "$locks_acquired" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $LOCKS_WAIT -eq 1 ]; then
    query="SELECT count(*) FROM pg_locks WHERE granted=false"
    locks_wait=`$PSQL_CMD "$query"`
    if [ $VERBOSE -eq 1 ]; then
        echo "locks_wait:$locks_wait"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "LocksWait" --value "$locks_wait" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Blocks
if [ $BLKS_READ -eq 1 ]; then
    query="SELECT sum(blks_read) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_blks_read=`$PSQL_CMD "$query"`
    prev_blks_read=`getCache "blks_read" $curr_blks_read`
    raw_blks_read=`expr $curr_blks_read - $prev_blks_read`
    blks_read=`expr $raw_blks_read / $time_interval`
    setCache "blks_read" $curr_blks_read
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_blks_read:$curr_blks_read"
        echo "prev_blks_read:$prev_blks_read"
        echo "raw_blks_read:$raw_blks_read"
        echo "blks_read:$blks_read"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "BlksRead" --value "$blks_read" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $BLKS_HIT -eq 1 ]; then
    query="SELECT sum(blks_hit) FROM pg_stat_database WHERE datname='$DBNAME'"
    curr_blks_hit=`$PSQL_CMD "$query"`
    prev_blks_hit=`getCache "blks_hit" $curr_blks_hit`
    raw_blks_hit=`expr $curr_blks_hit - $prev_blks_hit`
    blks_hit=`expr $raw_blks_hit / $time_interval`
    setCache "blks_hit" $curr_blks_hit
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_blks_hit:$curr_blks_hit"
        echo "prev_blks_hit:$prev_blks_hit"
        echo "raw_blks_hit:$raw_blks_hit"
        echo "blks_hit:$blks_hit"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "BlksHit" --value "$blks_hit" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Buffers
if [ $BUFFERS_CHECKPOINT -eq 1 ]; then
    query="SELECT buffers_checkpoint FROM pg_stat_bgwriter"
    curr_buffers_checkpoint=`$PSQL_CMD "$query"`
    prev_buffers_checkpoint=`getCache "buffers_checkpoint" $curr_buffers_checkpoint`
    raw_buffers_checkpoint=`expr $curr_buffers_checkpoint - $prev_buffers_checkpoint`
    buffers_checkpoint=`expr $raw_buffers_checkpoint / $time_interval`
    setCache "buffers_checkpoint" $curr_buffers_checkpoint
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_buffers_checkpoint:$curr_buffers_checkpoint"
        echo "prev_buffers_checkpoint:$prev_buffers_checkpoint"
        echo "raw_buffers_checkpoint:$raw_buffers_checkpoint"
        echo "buffers_checkpoint:$buffers_checkpoint"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "BuffersCheckpoint" --value "$buffers_checkpoint" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $BUFFERS_CLEAN -eq 1 ]; then
    query="SELECT buffers_clean FROM pg_stat_bgwriter"
    curr_buffers_clean=`$PSQL_CMD "$query"`
    prev_buffers_clean=`getCache "buffers_clean" $curr_buffers_clean`
    raw_buffers_clean=`expr $curr_buffers_clean - $prev_buffers_clean`
    buffers_clean=`expr $raw_buffers_clean / $time_interval`
    setCache "buffers_clean" $curr_buffers_clean
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_buffers_clean:$curr_buffers_clean"
        echo "prev_buffers_clean:$prev_buffers_clean"
        echo "raw_buffers_clean:$raw_buffers_clean"
        echo "buffers_clean:$buffers_clean"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "BuffersClean" --value "$buffers_clean" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

if [ $BUFFERS_BACKEND -eq 1 ]; then
    query="SELECT buffers_backend FROM pg_stat_bgwriter"
    curr_buffers_backend=`$PSQL_CMD "$query"`
    prev_buffers_backend=`getCache "buffers_backend" $curr_buffers_backend`
    raw_buffers_backend=`expr $curr_buffers_backend - $prev_buffers_backend`
    buffers_backend=`expr $raw_buffers_backend / $time_interval`
    setCache "buffers_backend" $curr_buffers_backend
    if [ $VERBOSE -eq 1 ]; then
        echo "curr_buffers_backend:$curr_buffers_backend"
        echo "prev_buffers_backend:$prev_buffers_backend"
        echo "raw_buffers_backend:$raw_buffers_backend"
        echo "buffers_backend:$buffers_backend"
    fi
    if [ $VERIFY -eq 0 ]; then
        /opt/aws/bin/mon-put-data --metric-name "BuffersBackend" --value "$buffers_backend" --unit "Count" $CLOUDWATCH_OPTS
    fi
fi

# Write cache buffer
writeCache

