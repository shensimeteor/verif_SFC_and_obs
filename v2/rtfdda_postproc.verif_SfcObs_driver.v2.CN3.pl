#!/usr/bin/perl
#arguments: -id GMID -m GFS_WCTRL [-o offset_hour | -v valid_datetime] -i verify_interval [-l max_verify_hours] [-d verify_incre_hour] [-p max_run_parallel]
#max_run_parallel: should depends on CPU cores & /dev/shm size
#sishen 2017-05-18
#sishen 2017-06-01, v2, support parallel running
#sishen 2017-08-20, reverse the order of submitting cycles (latest cycle first), update on VERIF_INTERVAL
#sishen 2017-10-02, add WRF_F plot_SFC_and_OBS here too
#----------------------------------
#parse arguments
#----------------------------------
@argus=@ARGV;
$narg=scalar(@argus);
$iarg=0;
while ($iarg < $narg) {
    if ( $argus[$iarg] eq "-id") {
        $GMID=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-m") {
        $MEMBER=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-v") {
        $VALID=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-o") {
        $OFFSET_HOUR=$argus[$iarg+1];
        $iarg+=2;
        $ttime=`date -d "$OFFSET_HOUR hours ago" +%Y%m%d%H`;
        chomp($ttime);
        $VALID=$ttime;
        next;
    }elsif ($argus[$iarg] eq "-i") {
        $VERIF_INTERVAL=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-l") {
        $MAX_VERIF_HOURS=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-d") {
        $VERIF_INCRE_HOUR=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-p") {
        $MAX_PARALLEL_RUN=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "--") {
        last;
    }
}
if ( ! ("$VALID" and "$GMID" and "$MEMBER" and "$VERIF_INTERVAL")) {
    print "<usage> : $0  -id GMID -m GFS_WCTRL [-v VALIDATE_TIME | -o OFFSET_HOUR] -i VERIF_INTERVAL [-l MAX_VERIF_HOURS] [-d VERIF_INCRE_HOUR] [-p MAX_PARALLEL_RUN] \n";
    print "- sishen, 2017-5-17 \n";
    exit(-1);
}
#----------------------------------
#define CONSTANTS
#----------------------------------
$HOMEDIR=$ENV{HOME};
$GMODDIR="$HOMEDIR/data/GMODJOBS/$GMID";
$RUNDIR="$HOMEDIR/data/cycles/$GMID/$MEMBER";
$ENSPROCS="$ENV{CSH_ARCHIVE}/ncl";
$MYLOGDIR="$HOMEDIR/data/cycles/$GMID/zout/postproc/ver$VALID";
$EXECUTOR="rtfdda_postproc.verif_SfcObs.v2.CN3.pl"; ##
system("test -d $MYLOGDIR || mkdir -p $MYLOGDIR");
require "$ENSPROCS/common_tools.pl";
require "$GMODDIR/flexinput.pl"; 
$valid_hour=substr($VALID, 8,2);
if($valid_hour % $CYC_INT != 0) {
    print "Error: Not a valid validate_time!\n";
    exit(-1);
}
if (! "$MAX_VERIF_HOURS") {
    $MAX_VERIF_HOURS=$FCST_LENGTH;
}
if (! "$VERIF_INCRE_HOUR") {
    $VERIF_INCRE_HOUR=1;
}
if (! "$MAX_PARALLEL_RUN") {
    $MAX_PARALLEL_RUN=1;
}
#--------------------
#do obs thin 
#--------------------
$do_thin="True";
if($do_thin == "True"){
     $CYCLE=$VALID;
     $dstart=&hh_advan_date($CYCLE, -$CYC_INT);
     $dend=$CYCLE;
     $WORKDIR="/dev/shm/postprocs/$GMID/obs_thin/";
     $OBS_BANK="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/thined_obs/";
     system("test -d $WORKDIR || mkdir -p $WORKDIR");
     &wait_qcoutraw_or_wrfp("$RUNDIR/$CYCLE", 60, 60);
     sleep(60);
     print("to run process_qc_out_SfcObs -------- \n");
     #thin obs
     $max_dom_obs_thin=3;
     $com_obs = "${GMODDIR}/process_qc_out_SfcObs.pl $CYCLE $dstart $dend $max_dom_obs_thin $GMID $MEMBER $WORKDIR/ >& $MYLOGDIR/zobs.sfcobs";
     print("$com_obs \n");
     system("date");
     system ("$com_obs");
     system("date");
     $d=$dstart;
     while ($d <= $dend) {
         for $domi (1..$max_dom_obs_thin) {
             #cp thined obs, for use of verification 
             $thined_obs_file="$WORKDIR/$CYCLE/$d/obs_thin/d$domi/$d.hourly.obs_sgl.nc";
             system("test -d $OBS_BANK/d$domi|| mkdir -p $OBS_BANK/d$domi");
             system("mv $thined_obs_file $OBS_BANK/d$domi/");
         }
         $d=&hh_advan_date($d, 1);
     }
     system("rm -rf $WORKDIR/");
     print("finished mv to OBS_BANK");
}
#--------------------
#do verif_SFC_and_obs
#--------------------
$start_try=&tool_date12_add("${VALID}00", -$MAX_VERIF_HOURS, "hours");
print $start_try."\n";
$start_try=substr($start_try, 0, 10);
$end_try=$VALID;
print $end_try."\n";
#$try=$start_try;
#$try=&hh_advan_date($end_try, -$VERIF_INTERVAL);
$try=$end_try;
while ($try >= $start_try) {
    #get start_hour, end_hour
    $temp=&tool_date12_diff_minutes("${VALID}00", "${try}00");
    $end_hour = $temp/60;
    $start_hour = $end_hour-$VERIF_INTERVAL+1;
    #run
    $cmd="$GMODDIR/$EXECUTOR -id $GMID -m $MEMBER -c $try -s $start_hour -e $end_hour -d $VERIF_INCRE_HOUR -log $MYLOGDIR >& $MYLOGDIR/zverif_obssfc.$try";
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
    $try=&hh_advan_date($try,-$VERIF_INTERVAL);
}


  #-----------------------------------------------------------------------------
  # 10.3 Subroutine to avance the date
  #-----------------------------------------------------------------------------
  # Name: hh_advan_date
  # Arguments: 1) a date as yyyymmddhh
  #            2) number of hours as an integer
  # Return: a date in 'yyyymmddhh'-form
  # Description: advances given date in 1st argument by the number of hours given
  #              in the second argument
  #----------------------------------------------------------------------------
  sub hh_advan_date {

  %mon_days = (1,31,2,28,3,31,4,30,5,31,6,30,7,31,8,31,9,30,10,31,11,30,12,31);
  (my $s_date, my $advan_hh) = @_ ;

  my $yy = substr($s_date,0,4);
  my $mm = substr($s_date,4,2);
  my $dd = substr($s_date,6,2);
  my $hh = substr($s_date,8,2);

  my $feb = 2;
  $mon_days{$feb} = 29 if ($yy%4 == 0 && ($yy%400 == 0 || $yy%100 != 0));

  $hh = $hh + $advan_hh;
  while($hh > 23) {
  $hh -= 24;
  $dd++;
  }
  while($dd > $mon_days{$mm+0}) {
  $dd = $dd - $mon_days{$mm+0};
  $mm++;
  while($mm > 12) {
  $mm -= 12;
  $yy++;
  }
  }
  while($hh < 0) {
  $hh += 24;
  $dd--;
  }
  if($dd < 1) {
  $mm--;
  while($mm < 1) {
  $mm += 12;
  $yy--;
  }
  $dd += $mon_days{$mm+0};
  }

  my $new_date = sprintf("%04d%02d%02d%02d",$yy,$mm,$dd,$hh);
  }

# if RAP_RTFDDA/raw or WRF_P exist, return; else, wait up to $max_wait * $wait_int_sec 
  sub wait_qcoutraw_or_wrfp{
      my ($cycle_rundir, $max_wait, $wait_int_sec) = @_;
      my $qcoutdir="$cycle_rundir/RAP_RTFDDA/";
      my $iwait=0;
      my $status=0; #1, exist; 0, no
      print("in wait_qcoutraw_or_wrfp --- \n");
      for ($iwait=0; $iwait < $max_wait; $iwait++){
          if ( -d "$cycle_rundir/WRF_P" ) {
              $status=1;
              $nqc=`ls -l $qcoutdir/qc_out* | wc -l `;
              print("WRF_P found, nqcout = $nqc, return\n");
              last;
          }elsif ( -d "$qcoutdir/raw/"){
              $status=1;
              sleep 50; 
              $nqc=`ls -l $qcoutdir/qc_out* | wc -l `;
              print("RTFDDA/raw found, nqcout = $nqc, return\n");
              last;
          }
          print("to wait, iwait=$iwait\n");
          sleep $wait_int_sec;
      }
      if($status==1){
          return "True";
      }else{
          print("max_wait exceed, return False\n");
          return "False";
      }
  }
