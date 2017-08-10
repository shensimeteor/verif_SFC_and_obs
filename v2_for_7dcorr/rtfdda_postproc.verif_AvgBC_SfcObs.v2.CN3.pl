#!/usr/bin/perl
#arguments: -id GMID -m GFS_WCTRL [-c CYCLE | -o offset] [-s start_hour] [-e end_hour] [-d incre_hour]
#v1, 2017-5-17
#v2, 2017-6-1, support subdomain, reading verif_sfcobs.input.pl
#dependencies: flexinput.pl verif_sfcobs.input.pl
#modify from rtfdda_postproc.verif_SfcObs.v2.CN3.pl, 2017.8.10, to verif_SfcObs for 7dAVG(corr.nc)
#need prepare HGT file (ensproc/nc_templates/GFS_WCTRL_auxhist3_d02_template_HGT.nc), 
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
    }elsif ($argus[$iarg] eq "--") {
        last;
    }
}
if ( ! ("$CYCLE" and "$GMID" and "$MEMBER")) {
    print "<usage> : $0  -id GMID -m GFS_WCTRL [-c CYCLE | -o offset] [-s start_hour] [-e end_hour] [-d incre_hour]\n";
    print "- sishen, 2017-5-17 \n";
    exit(-1);
}
$START_HOUR=0 if(! "$START_HOUR");
$END_HOUR=-1 if(! "$END_HOUR");
$INCRE_HOUR=1 if(! "$INCRE_HOUR");

#----------------------------------
#define CONSTANTS
#----------------------------------
$HOMEDIR=$ENV{HOME};
$GMODDIR="$HOMEDIR/data/GMODJOBS/$GMID";
$ENSPROCS="$ENV{CSH_ARCHIVE}/ncl";
#$RUNDIR="$HOMEDIR/data/cycles/$GMID/$MEMBER/";
#$ARCDIR="$HOMEDIR/data/cycles/$GMID/archive/$MEMBER/"; #aux_$cycle
$DATEDIR="$HOMEDIR/data/cycles/ensprocs/$GMID/process2/7dAVG/files/";
$OBS_BANK="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/thined_obs/";
$WEB_DEST="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/web/verif_7dAVG_SFCOBS/";
$WEB_DEST2="$HOMEDIR/data/cycles/$GMID/$MEMBER/postprocs/web/";
system("test -d $WEB_DEST || mkdir -p $WEB_DEST");
system("test -d $WEB_DEST/cycles/ || mkdir -p $WEB_DEST/cycles/");
system("test -d $WEB_DEST/gifs/ || mkdir -p $WEB_DEST/gifs/");

require "$GMODDIR/flexinput.pl";
if ($END_HOUR == -1 ) {
    $END_HOUR=$FCST_LENGTH;
}

if ( ! -e "$GMODDIR/verif_sfcobs.input.pl") {
    print "ERROR: $GMODDIR/verif_sfcobs.input.pl not exist, exit!\n";
    exit(-1);
}
require "$GMODDIR/verif_sfcobs.input.pl";
$n_subdom=scalar(@DOM_ID);

$WORKDIR="/dev/shm/postprocs/$GMID/verif_7dAVG_SFCOBS/$MEMBER";
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
        #get thined_obs
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
        #get 7dcorr.nc from $DATEDIR
        #--------------------
        system("test -d $mywork/wrfoutfile || mkdir -p $mywork/wrfoutfile");
        chdir("$mywork/wrfoutfile");
        #
        $file_template="$GMODDIR/ensproc/nc_templates/${MEMBER}_auxhist3_d0${dom_wrf}_template_HGT.nc";
        $file_template_work="$WORKDIR/template/${MEMBER}_auxhist3_d0${dom_wrf}_template_HGT.nc";
        $file_dir="$DATEDIR/$CYCLE";
        $file_corr=&tool_date12_to_outfilename("${CYCLE}_auxhist3_d0${dom_wrf}_", "${d}00", "_7dcorr.nc");
        if( -e "$file_dir/$file_corr") {
            system("cp $file_dir/$file_corr $mywork/wrfoutfile/");
            if ( -e $file_template_work){
                print("ncks -v HGT -A $file_template_work -o $file_corr \n");
                system("ncks -v HGT -A $file_template_work -o $file_corr");
            }elsif (-e $file_template) {
                system("test -d $WORKDIR/template || mkdir -p $WORKDIR/template");
                system("cp $file_template $file_template_work");
                print("ncks -v HGT -A $file_template_work -o $file_corr \n");
                system("ncks -v HGT -A $file_template_work -o $file_corr");
            }else{
                print("WARNING: $file_template not exist! Fail to add HGT \n");
            }
        #    $cmd="ncrename -v T2_corrected,T2 -v Q2_corrected,Q2 -v rh2_corrected,rh2 $file_corr";
            $cmd="ncrename -v T2_corrected,T2 -v Q2_corrected,Q2  $file_corr";
            print($cmd ."\n");
            system($cmd);
            $file_path="$mywork/wrfoutfile/$file_corr";
        }else{
            print("WARNING: $file_dir/$file_corr not exist, -- skip \n");
            next;
        }
        #--------------------
        #plot verification SFC_and_obs
        #--------------------
        system("test -d $mywork/plot || mkdir -p $mywork/plot");
        chdir("$mywork/plot");
        symlink("$file_path","wrfout_or_aux3reformated.nc");
        $fn="wrfout_or_aux3reformated.nc";
        symlink("$ENSPROCS/plot_SFC_and_obs_withStats.ncl","plot_SFC_and_obs.ncl");
        symlink("$GMODDIR/ensproc/stationlist_site_dom${dom_wrf}","stationlist_site_dom${dom_wrf}");
        symlink("$GMODDIR/ensproc/map.ascii","map.ascii");
        symlink("$GMODDIR/ensproc/ncl_functions/initial_mpres_d0${dom_wrf}.ncl", "initial_mpres.ncl");
        symlink("$GMODDIR/ensproc/ncl_functions/convert_figure.ncl", "convert_figure.ncl");
        symlink("$GMODDIR/ensproc/ncl_functions/convert_and_copyout.ncl", "convert_and_copyout.ncl");
        system("test -d upper_air || mkdir upper_air");
        $dest="$WEB_DEST/gifs/$d";
        system("test -d $dest || mkdir -p $dest");
        $dest2="$WEB_DEST/cycles/$CYCLE/$d";
        system("test -d $dest2 || mkdir -p $dest2");
        if($DOM_LAT1[$isub-1] < 0) {
            $iszoom="False";
        }else{
            $iszoom="True";
        }
        $ncl = "ncl 'cycle=\"$CYCLE\"' 'file_in=\"$fn\"' 'qcfile_sfc_in=\"$file_obs\"' 'dom=$dom' 'web_dir=\"$WEB_DEST/gifs/\"' 'latlon=\"True\"' 'zoom=\"$iszoom\"' 'lat_s=$DOM_LAT1[$isub-1]' 'lat_e=$DOM_LAT2[$isub-1]' 'lon_s=$DOM_LON1[$isub-1]' 'lon_e=$DOM_LON2[$isub-1]' plot_SFC_and_obs.ncl >& zout.nclSFC.d${dom}.log";
        print($ncl);
        system($ncl);
        chdir("$WORKDIR");
        system("date");
    }
    system("rm -rf $WORKDIR/$CYCLE/$d");
}
#since no background running, just delete this cycle temp dir 
system("rm -rf $WORKDIR/$CYCLE");

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

