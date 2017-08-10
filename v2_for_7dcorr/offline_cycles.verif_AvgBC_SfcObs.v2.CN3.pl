#!/usr/bin/perl
#to customize here
$start_cycle="2017080100";
$end_cycle="2017081000";
$verif_cycle_interval=12;
$GMID="GECN3KM";
$MEMBER="GFS_WCTRL";
$GMODDIR="$ENV{HOME}/data/GMODJOBS/$GMID/";
$start_hour=1;
$end_hour=72;
$VERIF_INCRE_HOUR=1;
$MAX_PARALLEL_RUN=8;


$ENSPROCS="$ENV{CSH_ARCHIVE}/ncl";
require "$ENSPROCS/common_tools.pl";
$HOMEDIR="$ENV{HOME}";

$MYLOGDIR="$HOMEDIR/data/cycles/$GMID/zout/postproc/offline_avgbc/";
$EXECUTOR="rtfdda_postproc.verif_AvgBC_SfcObs.v2.CN3.pl"; ##
system("test -d $MYLOGDIR || mkdir -p $MYLOGDIR");

$cycle=$start_cycle;
while ($cycle <= $end_cycle) {
    print("to process cycle=$cycle ------------ \n");
    $cmd="$GMODDIR/$EXECUTOR -id $GMID -m $MEMBER -c $cycle -s $start_hour -e $end_hour -d $VERIF_INCRE_HOUR >& $MYLOGDIR/zverif_avgbc_obssfc.$cycle";
    if($MAX_PARALLEL_RUN == 1){
        print($cmd."\n");
        system($cmd);
    }else{
        $n_runer=`ps aux | grep "$EXECUTOR.*$GMID" | grep -v "grep" | wc -l`;
        chomp($n_runer);
        print "n_runer=$n_runer \n";
        while($n_runer >= $MAX_PARALLEL_RUN) {
            print "to wait++, n_runer=$n_runer\n";
            sleep 30;
            $n_runer=`ps aux | grep "$EXECUTOR.*$GMID" | grep -v "grep" | wc -l`;
            chomp($n_runer);
        }
        print($cmd." & \n");
        system("$cmd &");
        sleep 10;
    }
    $cycle00=&tool_date12_add("${cycle}00", $verif_cycle_interval, "hour");
    $cycle=substr($cycle00,0,10);
}


