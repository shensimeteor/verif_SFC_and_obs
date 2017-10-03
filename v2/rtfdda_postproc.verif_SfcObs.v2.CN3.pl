#!/usr/bin/perl
#arguments: -id GMID -m GFS_WCTRL [-c CYCLE | -o offset] [-s start_hour] [-e end_hour] [-d incre_hour] [-log dirlog]
#v1, 2017-5-17
#v2, 2017-6-1, support subdomain, reading verif_sfcobs.input.pl
#2017-08-15, change to use plot_SFC_and_obs_new.ncl 
#2017-10-2, change to contain analysis plots, &, if OBS_BANK not there, do process_qc_out
#dependencies: flexinput.pl verif_sfcobs.input.pl etc.
#----------------------------------
#parse arguments
#----------------------------------
@argus=@ARGV;
$narg=scalar(@argus);
$iarg=0;
$START_HOUR = 0; #default
$END_HOUR = -99;
while ($iarg < $narg) {
    if ( $argus[$iarg] eq "-id") {
        $GMID=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-m") {
        $MEMBER=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-c") {
        $CYCLE=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-o") {
        $OFFSET_HOUR=$argus[$iarg+1];
        $iarg+=2;
        $ttime=`date -d "$OFFSET_HOUR hours ago" +%Y%m%d%H`;
        chomp($ttime);
        $CYCLE=$ttime;
        next;
    }elsif ($argus[$iarg] eq "-s") {
        $START_HOUR=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-e") {
        $END_HOUR=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-d") {
        $INCRE_HOUR=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "-log") {
        $mylogdir=$argus[$iarg+1];
        $iarg+=2;
        next;
    }elsif ($argus[$iarg] eq "--") {
        last;
    }
}
if ( ! ("$CYCLE" and "$GMID" and "$MEMBER")) {
    print "<usage> : $0  -id GMID -m GFS_WCTRL [-c CYCLE | -o offset] [-s start_hour] [-e end_hour] [-d incre_hour] [-log log_dir]\n";
    print "- sishen, 2017-5-17 \n";
    exit(-1);
}
$INCRE_HOUR=1 if(! "$INCRE_HOUR");

#----------------------------------
#define CONSTANTS
#----------------------------------
$HOMEDIR=$ENV{HOME};
$GMODDIR="$HOMEDIR/data/GMODJOBS/$GMID";
$ENSPROCS="$ENV{CSH_ARCHIVE}/ncl";
$RUNDIR="$HOMEDIR/data/cycles/$GMID/$MEMBER/";
if(! "$mylogdir") {
    $mylogdir="$HOMEDIR/data/cycles/$GMID/zout/postproc/cyc$CYCLE/";
}
$ARCDIR="$HOMEDIR/data/cycles/$GMID/archive/$MEMBER/"; #aux_$cycle
$OBS_BANK="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/thined_obs/";
$WEB_DEST="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/web/verif_SFCOBS/";
$WEB_DEST2="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/web/";
$DIR_STATS="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/web/stats_SFCOBS/$CYCLE";
system("test -d $WEB_DEST || mkdir -p $WEB_DEST");
system("test -d $WEB_DEST/cycles/ || mkdir -p $WEB_DEST/cycles/");
system("test -d $WEB_DEST/gifs/ || mkdir -p $WEB_DEST/gifs/");
system("test -d $DIR_STATS || mkdir -p $DIR_STATS"); 

require "$GMODDIR/flexinput.pl";
if ($END_HOUR == -99 ) {
    $END_HOUR=$FCST_LENGTH;
}

if ( ! -e "$GMODDIR/verif_sfcobs.input.pl") {
    print "ERROR: $GMODDIR/verif_sfcobs.input.pl not exist, exit!\n";
    exit(-1);
}
require "$GMODDIR/verif_sfcobs.input.pl";
$n_subdom=scalar(@DOM_ID);

$WORKDIR="/dev/shm/postprocs/$GMID/verif_SFCOBS/$MEMBER";
system("test -d $WORKDIR || mkdir -p $WORKDIR");
require "$ENSPROCS/common_tools.pl";

$h=$START_HOUR;
for ($h=$START_HOUR; $h<=$END_HOUR; $h=$h+$INCRE_HOUR) {
    $d=&hh_advan_date($CYCLE, $h); 
    print $h."\n";
    for $isub (1..$n_subdom) {
        $dom=$DOM_ID[$isub-1];
        $dom_obs=$OBS_DOM_ID[$isub-1];
        $dom_wrf=$WRF_DOM_ID[$isub-1];
        print("begin $d dom$dom (use obs: dom$dom_obs, wrf: dom$dom_wrf) --------------------\n");
        system("date");
        $mywork="$WORKDIR/$CYCLE/$d/d$dom/";
        #--------------------
        #copy thined_obs
        #--------------------
        $file_obs="$OBS_BANK/d${dom_obs}/${d}.hourly.obs_sgl.nc";
        if( -s $file_obs) {
            system("test -d $mywork/obs_thinned || mkdir -p $mywork/obs_thinned");
            system("cp $file_obs $mywork/obs_thinned");
        }else{
            print "\n Error: $file_obs NOT exist! \n";
            print " - next date\n";
            next;
        }
        #--------------------
        #get wrf files, from RUNDIR or ARCDIR: $file_path 
        #--------------------
        system("test -d $mywork/wrfoutfile || mkdir -p $mywork/wrfoutfile");
        chdir("$mywork/wrfoutfile");
        #test if aux3_reformatted.nc already exist (for subdomain, as they use their parent's file)
        $file_wrfdom_aux3="$WORKDIR/$CYCLE/$d/d${dom_wrf}/wrfoutfile/aux3_reformatted.nc";
        if(-e "$file_wrfdom_aux3") {
            symlink("$file_wrfdom_aux3", "aux3_reformatted.nc");
            $file_path="$mywork/wrfoutfile/aux3_reformatted.nc";
        }else{
            $file_name1=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", "");
            if($h < 0) {
                $file_path1="$RUNDIR/$CYCLE/WRF_F/$file_name1";
            }elsif($h == 0){
                $file_path1="$RUNDIR/$CYCLE/WRF_P/$file_name1";
                if( ! -e $file_path1) {
                    $file_path1 = "$RUNDIR/$CYCLE/WRF_F/$file_name1";
                }
            }else{
                $file_path1="$RUNDIR/$CYCLE/WRF_P/$file_name1";
            }
            $file_name2=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", ".nc4.p");
            $file_path2="$ARCDIR/aux3_$CYCLE/$file_name2";
            $file_name3=$file_name2;
            $file_path3="$RUNDIR/$CYCLE/WRF_P/$file_name3"; #temporary path
            if( -s "$file_path1" ) {
                system("cp $file_path1 $mywork/wrfoutfile/");
                $file_path="$mywork/wrfoutfile/$file_name1";
            }elsif(-s "$file_path2") {
                system("cp $file_path2 $mywork/wrfoutfile/");
                $file_name2_unpack=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", ".nc4");
                print("doing ncpdq unpacking..\n");
                system("ncpdq -O -U $file_name2 $file_name2_unpack && rm -rf $file_name2");
                print("doing nc4 to nc3..\n");
                $file_name2_nc3=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", ".nc");
                system("ncks -O -3 $file_name2_unpack $file_name2_nc3");
                $file_path="$mywork/wrfoutfile/$file_name2_nc3";
            }elsif(-s "$file_path3") {
                system("cp $file_path3 $mywork/wrfoutfile/");
                $file_name3_unpack=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", ".nc4");
                print("doing ncpdq unpacking..\n");
                system("ncpdq -O -U $file_name3 $file_name3_unpack && rm -rf $file_name3");
                print("doing nc4 to nc3..\n");
                $file_name3_nc3=&tool_date12_to_outfilename("auxhist3_d0${dom_wrf}_", "${d}00", ".nc");
                system("ncks -O -3 $file_name3_unpack $file_name3_nc3");
                $file_path="$mywork/wrfoutfile/$file_name3_nc3";
            }else{
                print("\nWarn: $file_path1 & $file_path2 & $file_path3 NOT found!\n");
                print(" - continue next date\n");
                next;
            }
            #reformat aux
            if( -s "$file_path") {
                symlink("$ENSPROCS/add_files.ncl", "add_files.ncl");
                $cmd="$ENSPROCS/reformat_aux3.pl $file_path aux3_reformatted.nc";
                print($cmd."\n");
                system($cmd);
            }else{
                print("\nError: $file_path NOT exist!\n");
                print(" - continue next date\n");
                next;
            }
            if( ! -s "aux3_reformatted.nc" ) {
                print("\nError: aux3_reformatted.nc NOT generated!\n");
                print(" - continue next date\n");
                next;
            }
            $file_path="$mywork/wrfoutfile/aux3_reformatted.nc";
        }
        #--------------------
        #plot verification SFC_and_obs
        #--------------------
        system("test -d $mywork/plot || mkdir -p $mywork/plot");
        chdir("$mywork/plot");
        symlink("$file_path","wrfout_or_aux3reformated.nc");
        $fn="wrfout_or_aux3reformated.nc";
        symlink("$ENSPROCS/plot_SFC_and_obs_new.ncl","plot_SFC_and_obs.ncl");
        symlink("$GMODDIR/ensproc/stationlist_site_dom${dom_wrf}","stationlist_site_dom${dom_wrf}");
        symlink("$GMODDIR/ensproc/map.ascii","map.ascii");
        symlink("$GMODDIR/ensproc/ncl_functions/initial_mpres_d0${dom}.ncl", "initial_mpres.ncl"); #
        symlink("$GMODDIR/ensproc/ncl_functions/convert_figure.ncl", "convert_figure.ncl");
        symlink("$GMODDIR/ensproc/ncl_functions/convert_and_copyout.ncl", "convert_and_copyout.ncl");
        system("test -d upper_air || mkdir upper_air");
#        $dest="$WEB_DEST/gifs/$d";
#        system("test -d $dest || mkdir -p $dest");
        $dest2="$WEB_DEST/cycles/$CYCLE/$d";
        system("test -d $dest2 || mkdir -p $dest2");
        if($DOM_LAT1[$isub-1] < 0) {
            $iszoom="False";
        }else{
            $iszoom="True";
        }
        $file_stats="$DIR_STATS/d${dom}_${d}_stats.txt"; 
        $ncl = "ncl 'cycle=\"$CYCLE\"' 'file_in=\"$fn\"' 'qcfile_sfc_in=\"$file_obs\"' 'dom=$dom' 'web_dir=\"$WEB_DEST/gifs/\"' 'latlon=\"True\"' 'zoom=\"$iszoom\"' 'lat_s=$DOM_LAT1[$isub-1]' 'lat_e=$DOM_LAT2[$isub-1]' 'lon_s=$DOM_LON1[$isub-1]' 'lon_e=$DOM_LON2[$isub-1]' 'showStats=\"True\"' 'fileStats=\"$file_stats\"' 'optOutput=\"cycleOnly\"' 'filterQCValue=3' plot_SFC_and_obs.ncl >& zout.nclSFC.d${dom}.log";
        print($ncl);
        system($ncl);
        chdir("$WORKDIR");
        #to overwrite cycles & gifs
      #  $dest_cp="$WEB_DEST2/cycles/$CYCLE/$d";
      #  system("test -d $dest_cp || mkdir -p $dest_cp");
      #  system("cp -rf $dest2/* $dest_cp/");
        $dest_cp1="$WEB_DEST2/cycles/$CYCLE";
        $dest_cp2="$WEB_DEST2/cycles/${CYCLE}v";
        if(-d "$dest_cp1") {
            system("test -d $dest_cp1/$d || mkdir -p $dest_cp1/$d");
            system("cp -rf $dest2/* $dest_cp1/$d/");
            if($h > 0 ) {system("mv $dest_cp1 $dest_cp2")};
        }elsif (-d "$dest_cp2") {
            system("test -d $dest_cp2/$d || mkdir -p $dest_cp2/$d");
            system("cp -rf $dest2/* $dest_cp2/$d/");
        }else{
            system("test -d $dest_cp2/$d || mkdir -p $dest_cp2/$d");
            system("cp -rf $dest2/* $dest_cp2/$d/");
        }
        system("date");
    }
    system("rm -rf $WORKDIR/$CYCLE/$d");
}
#since no background running, just delete this cycle temp dir 
system("rm -rf $WORKDIR/$CYCLE");
#clean old WEB_DEST (verif_SFCOBS/cycles), because figures are cped to WEB_DEST2 (cycles/)
&clean_dir("$WEB_DEST/cycles", 14);
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


  sub clean_dir {
        my ($cleandir, $nbfi) = @_;
        @dclean = `ls -d $cleandir\/*20*`;
        $numd = @dclean;
        if ($numd > $nbfi ) {
                $ndel = $numd - $nbfi ;
                $ndel--;
                @rdirs = @dclean[0 .. $ndel];
                foreach  $rdir (@rdirs)  {
                        chomp $rdir;
                        system ("rm -rf $rdir");
                }
        }
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



