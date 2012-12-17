use CGI;

#$SL_session_dir     = "/home/camera-annotation/webcomp/web-session";
$SL_session_dir     = "/home/validation/camera/release/rammcap";
#$SL_rammcap_dir     = "/home/thumper6/webcomp/RAMMCAP-ann";
$SL_rammcap_dir     = "/home/validation/camera/release/bin/rammcap/RAMMCAP-ann";
$SL_rammcap_core_dir= "$SL_rammcap_dir/rammcap";
$SL_bin_dir         = "$SL_rammcap_dir/bin";
$SL_script_dir      = "$SL_rammcap_dir/scripts";
$SL_qsub_no_1       = 1;
$SL_qsub_no_2       = 2;
$SL_qsub_no_4       = 4;
$SL_qsub_no_8       = 8;
$SL_qsub_no_16      = 10;
$SL_qsub_no_32      = 12;
$SL_qsub_no_64      = 24;
$SL_qsub_no_128     = 32;


sub SL_query_cmd {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);
  my $sh  = "$dir/run.sh";

  my $cmd = `cat $sh`;
  print $cmd;
}########## END SL_query_cmd


sub SL_job_status {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);
  my $stat_file = "$dir/status";

  opendir(DIR, $dir);
  my @fs = grep {/webcomp.e\d+/} readdir(DIR);
  closedir(DIR);

  my $cmd;

  if (@fs) { #qsub
    #my @qids = map{substr($_,9);} @fs;
    #$cmd = `/opt/gridengine/bin/lx26-amd64/qstat | grep webcomp`;
    my @qids = map{$_ =~ /webcomp\.e(\d+)/; $1;} @fs;
    $cmd = `/opt/gridengine/bin/lx26-amd64/qstat | grep apache`;
    my @lls = split(/\n/, $cmd);
    my @running_ids = map { $_ =~ /(\d+)/; $1;} @lls;
    my %running_ids = map { $_, 1} @running_ids;

    $cmd = "completed";
    foreach my $i (@qids) {
      $cmd = "started" if ( $running_ids{$i} );
    }
  }
  else {
    $cmd = `tail --lines=1 $stat_file`;
  }
  print $cmd;
}########## END SL_job_status


sub SL_query_env {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);
  my $env_file  = "$dir/env";

  my $cmd = `cat $env_file`;
  print $cmd;
}########## END SL_query_env


sub SL_file_list {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);

  opendir(DIR, $dir) || bomb_error("Can not open dir $dir");
  my @files = readdir(DIR);
  closedir(DIR);

  foreach my $i (@files) {
    next if ($i eq ".");
    next if ($i eq "..");
    print "$i\n";
  }
}########## END SL_file_list


sub SL_file_view {
  my ($cgi_id, $PB) = @_;
  my ($i, $j, $k);
  my $dir = SL_session_dir($cgi_id);
  my $f = $PB->param("file");

  my @path = split(/\//, $dir);
  my $uid = $path[-3];
  my $wid = $path[-2];

  if (-d "$dir/$f") {
    opendir(DIR, "$dir/$f");
    my @f = grep {/\w/} readdir(DIR);
    closedir(DIR);

    my $fno = $#f+1;
    print <<EOD;
Directory $f contains $fno files:<P>
EOD
   for ($i=0; $i<$fno; $i++) {
     $j = $i+1; $k=$f[$i];
     print <<EOD;
$j <a href="q.cgi?uid=$uid&wid=$wid&id=$cgi_id&cmd=file-view&file=$f/$k">$k</A><br>
EOD
    } 
  }
  else {
    my $type = (split(/\./,$f))[-1];
    if ($type =~ /^png|gif$/i) {
      print <<EOD;
<img src="q.cgi?uid=$uid&wid=$wid&id=$cgi_id&cmd=file-download&file=$f">
EOD
    }
    else {

      print "<PRE>";
      my $cmd = `cat $dir/$f`;
      print $cmd;
      print "</PRE>";
    }
  }
}########## END SL_file_view


sub SL_file_download {
  my ($cgi_id, $PB) = @_;
  my ($i, $j, $k);
  my $dir = SL_session_dir($cgi_id);
  my $f = $PB->param("file");

  my @path = split(/\//, $dir);
  my $uid = $path[-3];
  my $wid = $path[-2];

  if (-d "$dir/$f") {
    print "Content-type: text/html\n\n";

    opendir(DIR, "$dir/$f");
    my @f = grep {/\w/} readdir(DIR);
    closedir(DIR);

    my $fno = $#f+1;
    print <<EOD;
Directory $f contains $fno files:<P>
EOD
   for ($i=0; $i<$fno; $i++) {
     $j = $i+1; $k=$f[$i];
     print <<EOD;
$j <a href="q.cgi?uid=$uid&wid=$wid&id=$cgi_id&cmd=file-download&file=$f/$k">$k</A><br>
EOD
    } 
  }
  else {
    print "Content-type: application/unknown.file\n\n";
    #my $cmd = `cat $dir/$f`;
    #print $cmd;
    open(fl, "$dir/$f");
    my $line;
    while($line = <fl>){
       print "$line";
    }
    close(fl);
  }
}########## END SL_file_download


sub SL_file_path {
  my ($cgi_id, $PB) = @_;
  my $dir = SL_session_dir($cgi_id);
  my $f = $PB->param("file");

  print "$dir/$f\n";
}########## END SL_file_path


sub SL_kill_job {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);
  my $dirn = $dir . "k";
  my $cmd = `mv -f $dir $dirn`;
}########## END SL_kill_job


sub SL_job_submit {
  my ($cgi_id, $cmd_opt, $app_spec, $idx) = @_;

  if ($cmd_opt =~ /;/) {
    bomb_error("invalid command:\n $cmd_opt");
  }

  SL_job_qsub($cgi_id, $cmd_opt, $app_spec, $idx); return;
  my $dir = SL_session_dir($cgi_id);
  my $sh  = "$dir/run.sh";
  my $stat_file = "$dir/status";
  my $env_file  = "$dir/env";

  open(OUT, "> $sh") || bomb_error("can not write to file $sh");
  print OUT "$cmd_opt\n";
  print OUT "echo completed >> $stat_file\n";
  close(OUT);

  my $cmd = `env > $env_file`;
     $cmd = `echo started >> $stat_file`;
     $cmd = `sh $sh > /dev/null&`;  
}########## END SL_job_submit


sub SL_job_qsub {
  my ($cgi_id, $cmd_opt, $app_spec, $idx) = @_;
  my ($i, $j, $k);
  my $dir = SL_session_dir($cgi_id);
  my $sh  = "$dir/run.sh";
     $sh  = "$sh.$idx" if (defined($idx));
  my $stat_file = "$dir/status";
  my $env_file  = "$dir/env";
  my $err_file  = "$dir/err";
  my $pwd = `pwd`;
  my $path = "$SL_bin_dir:$ENV{'PATH'}";

  my $usrid = (split(/\//,$dir))[-3];
     $usrid =~ s/\s//g;
     $usrid =~ s/\W/X/g;
     $usrid =~ s/^[0-9]/X/;

  my $jobname = $usrid . "_webcomp";
     
  #  $jobname = "webcomp";

  my $queue = "";
  if ($app_spec->{'queue'}) {$queue = "-q $app_spec->{'queue'}";}

  open(OUT, "> $sh") || bomb_error("can not write to file $sh");
  print OUT <<EOD;
#!/bin/sh
#\$ -S /bin/bash
#\$ -v PATH=$path

cd $SL_rammcap_dir
$cmd_opt 
echo completed >> $stat_file
EOD
  close(OUT);

  my $cmd;
     $cmd = `env > $env_file`;
     $cmd = `echo started >> $stat_file`;

  if (not defined($app_spec->{'no_qsub'})) {
    $cmd = `/opt/gridengine/bin/lx26-amd64/qsub $queue -N $jobname -o $dir -e $dir $sh >> $err_file 2>&1`;
  }
  else {
    for ($i=0; $i<$app_spec->{'no_qsub'}; $i++) {
      $cmd = `/opt/gridengine/bin/lx26-amd64/qsub $queue -N $jobname -o $dir -e $dir $sh >> $err_file 2>&1`;
      sleep(1);
    }
  }
}########## END SL_job_qsub


sub SL_print_content_type {
  my $send_to = shift;

  #if    ($send_to eq "file") { print "Content-type: application/unknown.file\n\n"; }
  # actually print Content-type later, such as in SL_file_download()
  if    ($send_to eq "file") { ; } 
  elsif ($send_to eq "text") { print "Content-type: text/plain\n\n"; }
  elsif ($send_to eq "html") { print "Content-type: text/html\n\n"; }
  else                       { print "Content-type: text/plain\n\n"; }
}########## END print_content_type


sub SL_session_dir {
  my $sid = shift;
  my $uid = shift;
  my $wid = shift;

  if ($uid and $wid) {
    return "$SL_session_dir/$uid/$wid/$sid";
  }
  else {
    return "$SL_session_dir/$sid";
  }
}########## END session_dir

#update $SL_session_dir => $SL_session_dir/$uid/$wid
sub SL_session_dir_update {
  my $PB = shift;
  my $uid = $PB->param("uid");  $uid =~ s/\s//g;  $uid = "guest" unless defined($uid);
  my $wid = $PB->param("wid");  $wid =~ s/\s//g;

  if (not defined($wid)){
    my $id1 = `date +%C%y%m%d%H%M%S`; chop($id1);
    $wid = $id1. $$;
    my $cmd = `mkdir -p $SL_session_dir/$uid/$wid`;
  }

  if (-e "$SL_session_dir/$uid/$wid") {
    $SL_session_dir = "$SL_session_dir/$uid/$wid";
  }
}
########## END SL_session_dir_update


sub SL_print_session_dir {
  print "$SL_session_dir\n<P>";
}
########## END SL_print_session_dir

sub SL_new {
  my ($uid, $wid) = @_;
  if ($uid and $wid) {
    return "false" if (-e "$SL_session_dir/$uid/$wid");
    my $cmd = `mkdir -p $SL_session_dir/$uid/$wid`;
    return "false" unless (-e "$SL_session_dir/$uid/$wid");
    #return "$uid/$wid";
    return "true";
  }
  #return "wrong $uid $wid\nmkdir -p $SL_session_dir/$uid/$wid";
  return "false";
}########## END SL_new


sub SL_session_init {
  my $name = shift;
  my $id0 = int(rand() * 1000000);
  my $id1 = `date +%C%y%m%d%H%M%S`; chop($id1);

  my $sid = sprintf("%6s",$id0) . $id1 . sprintf("%6s",$$);
     $sid =~ s/ /0/g;
     $sid .= ".$name" if ($name =~ /\w/);

  my $dir = SL_session_dir($sid);
  SL_bomb_error("session dir exist: $dir") if (-e $dir);
  my $cmd = `mkdir $dir`;
  SL_bomb_error("unable to create session dir: $dir") unless (-e $dir);

  return $sid;
}########## END session_init 


sub SL_prepare_input_file {
  my ($i, $j, $k, $ll);
  my ($PB, $cgi_id, $id, $new_file_name) = @_;
  my $file_path = undef;

  my $input_mode = $PB->param("input".$id);
     $input_mode = "upload" unless ($input_mode);

  if ($input_mode eq "local") {
    $file_path = $PB->param("file_path".$id);
    if (not defined($file_path)) {
      my $up_stream_id = $PB->param("upsid".$id);
      my $up_stream_f  = $PB->param("upsfile".$id);
         $up_stream_f  = "output.1" unless (defined($up_stream_f));
      $file_path = SL_session_dir($up_stream_id) . "/$up_stream_f";
    }
    $file_path =~ s/\s//g;
  }
  elsif ($input_mode eq "upload") {
    my $fh = $PB->param("file".$id);
    $file_path = SL_session_dir($cgi_id) . "/input.$id";
   
    `ln -s $fh $file_path`;
    goto JJJJ;
    open(UPLOADFILE, "> $file_path" ) || SL_bomb_error("Can not write to $file_path");
    binmode(UPLOADFILE);
    while ($ll=<$fh>) {
      $ll=~s/\r/\n/g;
      $ll=~s/\n\n/\n/g;
      print UPLOADFILE $ll;
    }
    close(UPLOADFILE);
   JJJJ:;
  }

  SL_bomb_error("Can not write to $file_path or LOCAL file $file_path doesn't exist") unless (-e $file_path);

  if ($new_file_name) {
    my $cmd = `ln -s $file_path $new_file_name`;
    SL_bomb_error("Can not write to $new_file_name") unless (-e $new_file_name);
    return $new_file_name;
  }
  else { return $file_path; }
}########## END write_uploaded_files


sub SL_print_help {
  my $help_info = shift;
  my $cgi = $ENV{"SERVER_NAME"} . $ENV{"SCRIPT_NAME"};
     $cgi = $0 unless $cgi;

  print <<EOD;
CGI options:
$cgi?cmd=help|run|query|cmd|env|file-list|file-download|file-path|kill-job
	help:	print usage
	run:	run web service, return JOB_ID
		see bottom for other input options
	query:	query job status, return status code []
		$cgi?cmd=query&id=JOB_ID
        cmd:	query command line options, return actual command line
		$cgi?cmd=cmd&id=JOB_ID
	env:	print environment variables
		$cgi?cmd=cmd&id=JOB_ID
	file-list:	list files, return a list of input/output files
		$cgi?cmd=file-list&id=JOB_ID
	file-download:	download a specific file
		$cgi?cmd=file-download&id=JOB_id&file=FILE_NAME
	file-fiew:	view a specific file
		$cgi?cmd=file-view&id=JOB_id&file=FILE_NAME
	file-path:	return local path of a specific file
		$cgi?cmd=file-path&id=JOB_id&file=FILE_NAME
	kill-job:	kill job
		$cgi?cmd=kill-job&id=JOB_id

------------------------------------------------------------------------------
More options for cmd=run:
A web service many have ONE or more input files, each file can be uploaded
or can be specified as a path within local file system where the web wervice runs.

To upload the FIRST file:
<input type="hidden" name="input1" value="upload"  />
<input type="file"   name="file1" />

To use local path for the FIRST file:
<input type="hidden" name="input1"      value="local"  />
<input type="hidden" name="file_path1"  value="/home/some_dir/some_dir1/some_filename" />
	"/home/some_dir/some_dir1/some_filename" can be returned from another web 
	service

To upload the SECOND file:
<input type="hidden" name="input2" value="upload"  />
<input type="file"   name="file2" />

To use local path for the SECOND file:
<input type="hidden" name="input2" value="local"  />
<input type="hidden" name="file_path2"  value="/home/some_dir/some_dir1/some_filename" />

More input files can be specified in a similar way.
------------------------------------------------------------------------------

$help_info
EOD
}########## END print_help_general


sub SL_print_form {
  my ($PB, $no_input_files) = @_;
  my ($i, $j, $k);
  my $script_name = (split(/\//,$0))[-1];
  print <<EOD;
<form name="web" action="$script_name" method="post" enctype="multipart/form-data" />
<HR>
EOD

  for ($i=1; $i<=$no_input_files; $i++) { 
    my $n1 = "input"     .$i;
    my $f1 = "file"      .$i;
    my $p1 = "file_path" .$i;
    print <<EOD;
Input file #$i:
<input type="radio"  name="$n1" value="upload" checked="checked" />upload
<input type="radio"  name="$n1" value="local"                    />local
File: <input type="file"   name="$f1"               /><BR>
Local path: <input type="text"   name="$p1"  size=60 /><BR>
EOD
  }
  print <<EOD;
<HR>
Command line option: <input type="text"   name="cmd_opt"     size=60 /><BR>
<input type="submit" name="cmd"         value="run" />
</form>
EOD
}########## END SL_print_form


sub SL_print_report {
  my $cgi_id = shift;
  my $dir = SL_session_dir($cgi_id);
  my $report = `cat $dir/report`;

  my $sh_string = "";
  if (-e "$dir/run.sh") {$sh_string = "<HR><H1>Command line:</h1>\n" . `cat $dir/run.sh`;}

  my $env_string = "";
  if (-e "$dir/env")     {$env_string = "<HR><H1>Environmental variables:</h1>\n" . `cat $dir/env`;}

  my $log_string = "";
  if (-e "$dir/log")     {$log_string = "<HR><H1>LOG file, error etc.:</h1>\n". `cat $dir/log`; }

  my $cpu_string = "";
  if (-e "$dir/log.cpu") {
    my $s = 0;
    my $ll;
    open(TTT, "$dir/log.cpu") || die "can not open file $dir/log.cpu \n";
    while($ll = <TTT>) {
      chop($ll); $s += (split(/\s+/,$ll))[-1];
    }
    close(TTT);
    my $s0  = $s;
    my $day = int($s/3600/24); $s = $s%(3600*24);
    my $h   = int($s/3600);    $s = $s%3600;
    my $m   = int($s/60);      $s = $s%60;
    $cpu_string = "<HR><H1>CPU time:</h1>\n total $s0(seconds)<BR>\n $day day(s), $h hour(s), $m minute(s), $s second(s)\n";
  }


  print <<EOD;
<PRE>
$report
$sh_string
$cpu_string
$log_string
$env_string
</PRE>
EOD
}########## END SL_print_report


sub SL_report {
  my ($cgi_id, $title, %files) = @_;
  my ($i, $j, $k);
  my $dir = SL_session_dir($cgi_id);
  my $report = "$dir/report";

  my @files = sort keys %files;
  my $file_string = "<h1>Service: $title</H1><HR>\n<H1>Input/Output files:</H1>\n";

  foreach $i (@files) {
    my $path = $files{$i};
    my @path = split(/\//, $path);
    my $uid = $path[-4];
    my $wid = $path[-3];
    my $p = $path[-2];
    my $f = $path[-1];

    $file_string .= <<EOD;
$i, <A href="q.cgi?uid=$uid&wid=$wid&cmd=file-download&id=$p&file=$f">download</A>, <A href="q.cgi?uid=$uid&wid=$wid&cmd=file-view&id=$p&file=$f">view</A>
EOD
  }

  open(REP, "> $report") || SL_bomb_error("Can not write to $report");
  print REP $file_string;
  close(REP);
}########## END SL_report


sub SL_XML_report {
  my ($cgi_id, $xml) = @_;
  my ($i, $j, $k);
  my $dir = SL_session_dir($cgi_id);
  my $report = "$dir/report.xml";

  open(XMLRPT, "> $report") || SL_bomb_error("Can not write to $report");
  print XMLRPT $xml;
  close(XMLRPT);
}
########## END SL_XML_report


sub SL_other_cmds {
  my ($cgi_id, $cgi_cmd, $PB, $app_spec) = @_;

  if    ($cgi_cmd eq "help"         ) { SL_print_help($app_spec->{'help_info'});}
  elsif ($cgi_cmd eq "query"        ) { SL_job_status($cgi_id);}
  elsif ($cgi_cmd eq "cmd"          ) { SL_query_cmd($cgi_id); }
  elsif ($cgi_cmd eq "env"          ) { SL_query_env($cgi_id); }
  elsif ($cgi_cmd eq "file-list"    ) { SL_file_list($cgi_id); }
  elsif ($cgi_cmd eq "file-download") { SL_file_download($cgi_id, $PB); }
  elsif ($cgi_cmd eq "file-view"    ) { SL_file_view($cgi_id, $PB); }
  elsif ($cgi_cmd eq "file-path"    ) { SL_file_path($cgi_id, $PB); }
  elsif ($cgi_cmd eq "kill-job"     ) { SL_kill_job($cgi_id);      }
  elsif ($cgi_cmd eq "form"         ) { SL_print_form($PB, $app_spec->{'no_input_files'}); }
  elsif ($cgi_cmd eq "report"       ) { SL_print_report($cgi_id); }
  else                                { SL_print_help($app_spec->{'help_info'});}

}########## END SL_other_cmds


sub SL_bomb_error {
  my $message = shift;

  print $message;
  die   $message;
}########## END SL_bomb_error


########################
#URL ESCAPE CODES
#
#     CHAR     ESC
#     ------   ----
#     SPACE    %20
#     #        %23
#     $        %24
#     %        %25
#     &        %26
#     /        %2F
#     :        %3A
#     ;        %3B
#     <        %3C
#     =        %3D
#     >        %3E
#     ?        %3F
#     @        %40
#     [        %5B
#     \        %5C
#     ]        %5D
#     ^        %5E
#     `        %60
#     {        %7B
#     |        %7C
#     }        %7D
#     ~        %7E
########################

1;

