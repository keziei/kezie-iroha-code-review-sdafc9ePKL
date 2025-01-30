#!/bin/bash
# KI Check memory adjustment without adjusting
export SW_VER=`echo $ORACLE_HOME | awk -F "/" '{print $6}' | awk -F "." '{print $1}'`;

## check os user is oracle
WHOAMI=`whoami`
if [ $WHOAMI != "oracle" ]; then
    echo $0: Should run as the oracle user
    exit 1
fi

os_memG ()
{ echo "(`grep MemTotal /proc/meminfo | awk '{print $2}'` /1024 )" | bc
}

if [ `os_memG` -le `echo "(5 * 1024)" | bc` ]; then
os_alloc_percent=0.5
elif [ `os_memG` -le `echo "(7 * 1024)" | bc` ]; then
os_alloc_percent=0.6
elif [ `os_memG` -le `echo "(9 * 1024)" | bc` ]; then
os_alloc_percent=0.62
elif [ `os_memG` -le `echo "(13 * 1024)" | bc` ]; then
os_alloc_percent=0.67
elif [ `os_memG` -le `echo "(19 * 1024)" | bc` ]; then
os_alloc_percent=0.75
elif [ `os_memG` -le `echo "(23 * 1024)" | bc` ]; then
os_alloc_percent=0.81
elif [ `os_memG` -le `echo "(27 * 1024)" | bc` ]; then
os_alloc_percent=0.84
elif [ `os_memG` -le `echo "(35 * 1024)" | bc` ]; then
os_alloc_percent=0.87
elif [ `os_memG` -le `echo "(69 * 1024)" | bc` ]; then
os_alloc_percent=0.90
elif [ `os_memG` -gt `echo "(69 * 1024)" | bc` ]; then
os_alloc_percent=0.93
fi

# Additional DB Parameters
FAST_SIZE ()
{ echo "( `df -P /Fast_Recovery | awk 'NR==2 {print $2}'` /1024/1024 )" | bc
}

#sga rounding /1
os_sga ()
{ echo "(`os_memG` * $os_alloc_percent) * .80 /1" | bc
}

#db cache rounding /1
os_dcz ()
 { echo "(`os_sga` * .5 ) /1" | bc
}

#shared pool rounding /1
os_spz ()
 { echo "(`os_sga` * .25 ) /1" | bc
}

if [ $SW_VER -ne 11 ]; then
    #pga >11g use one third, doubled for pga_limit. That is, 1/3 pga_aggregate_target, 2/3 pga_limit
    os_pgz ()
    { echo "(`os_memG` * $os_alloc_percent) * .20 * .333 /1" | bc
    }
else
    #pga 11g does not have pga_limit
    os_pgz ()
    { echo "(`os_memG` * $os_alloc_percent) * .20 /1" | bc
    }
fi

os_pgzlim ()
 { echo "(`os_pgz` * 2 )" | bc
}

if [ `os_pgzlim` -le 3096 ]; then
    os_pgzlimz=3096
    else 
    os_pgzlimz=`os_pgzlim`
fi

os_alloc_percent2=`echo "($os_alloc_percent * 100)" | bc`

echo Total Memory GB `os_memG`
echo "Memory allocation % is:" $os_alloc_percent2
echo SGA MB `os_sga`
echo Buffer Cache MB `os_dcz`
echo Shared Pool MB `os_spz`
echo PGA Target MB `os_pgz`
if [ $SW_VER -ne 11 ]; then
echo PGA Aggregate Limit MB $os_pgzlimz
else
echo "PGA Aggregate Limit will not be set"
fi
