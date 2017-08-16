undef("get_wrf_obs_stats")
;return stats(0:mean_obs; 1:mean_wrf_pt; 2:bias; 3:mae; 4:corr; 5:rmse; 6:nobs); stats@names for 6 names
function get_wrf_obs_stats(lon2d:numeric, lat2d:numeric, var2d:numeric, lon_obs:numeric, lat_obs:numeric, var_obs:numeric)
local wrf_pt, stats
begin   
    wrf_pt=rcm2points(lat2d, lon2d, var2d, lat_obs, lon_obs, 2)
    stats=new((/7/),float, -999.)
    idx=ind(.not. ismissing(var_obs))
    stats(0)=avg(var_obs(idx))
;    print((/"any_missing_varobs="+any(ismissing(var_obs))/))
    stats(1)=avg(wrf_pt(idx))
    stats(2)=avg(wrf_pt(idx) - var_obs(idx))
    stats(3)=avg(abs(wrf_pt(idx) - var_obs(idx)))
    stats(4)=escorc(ndtooned(wrf_pt(idx)), ndtooned(var_obs(idx)))
    stats(5)=dim_rmsd(ndtooned(wrf_pt(idx)), ndtooned(var_obs(idx)))
    stats(6)=dimsizes(idx)
    stats@names=(/"AVG_OBS", "AVG_PTWRF", "BIAS", "MAE", "CORR", "RMSE", "NOBS"/)
    return(stats)
end 

undef("add_stats")
;STAT is result of get_wrf_obs_stats; return plt(2)
function add_stats(wks, plot, STAT, txres, amres_tr)
local line,plt
begin
    line = "NOB:  " +sprinti("%0.4i", tointeger(STAT(6))) + "~C~" +\
           "OBS:  " +sprintf("%4.2f",STAT(0)) +"~C~"+ \
           "WRF:  " +sprintf("%4.2f",STAT(1)) +"~C~"+ \
           "BIAS: " +sprintf("%4.2f",STAT(2)) +"~C~"+ \
           "MAE:  " +sprintf("%4.2f",STAT(3)) +"~C~"+ \
           "COR:  " +sprintf("%4.2f",STAT(4)) +"~C~"+ \
           "RMS:  " +sprintf("%4.2f",STAT(5))
    plt=new((/2/), graphic)
    plt(0) = gsn_create_text(wks, line,txres)
    plt(1) = gsn_add_annotation(plot, plt(0), amres_tr)
    return(plt)
end 

undef("save_stats")
procedure save_stats(STAT, varname, file_save)
local str_stat, str_title
begin
    str_title="varname, NOB, OBS, WRF, BIAS, MAE, CORR, RMS"
    str_stat=varname+sprinti(",%4i,", tointeger(STAT(6))) + \
             sprintf("%4.2f,",STAT(0)) + sprintf("%4.2f,",STAT(1)) + \
             sprintf("%4.2f,",STAT(2)) + sprintf("%4.2f,",STAT(3)) + \
             sprintf("%4.2f,",STAT(4)) + sprintf("%4.2f", STAT(5))
    system("test -e "+file_save+" || echo "+str_title+" > "+file_save)
    system("echo "+str_stat+ " >> " +file_save)
end
                  
