
use strict; 
use warnings; 
use Data::Dumper qw(Dumper);

#Grabs currently running process info using ps -ef 
#gets PID and the program name from PS using RegEx Capture groups 
# ps -el -o pid,s,cmd
#  PID S COMMAND
#    0 T sched

sub get_ps_info {
    my @process_array;
    my $result = `ps -el -o pid,s,cmd`;
    my @list = split(/\n/, "$result");
    for my $element (@list){
        if ($element =~ /PID\s+S\s+COMMAND/){
            next;
        }
        elsif ($element =~ /\s*(\S+)\s+(\S)\s+(.*)/){
            my @array = ($1,$2,$3);
            push(@process_array,[@array]);
        }
    }
    return \@process_array;
}

sub check_if_other_doctor_is_alive {
    my $ps_list = $_[0]; 
    my $doctor_name1 = $_[1];
    my $doctor_name2 = $_[2];
    my @ps_list = @{$ps_list};
    my $flag = 0; 
    for my $process (@ps_list){
        if($process->[2] =~ /$doctor_name1/){
            my $value = $process->[2];
            $flag = 1;
        }
        if($process->[2] =~ /$doctor_name2/){
            my $value = $process->[2];
            $flag = 1;
        }
    }
    if ($flag == 1){
        return 1; 
    }
    else{
        return 0; 
    }
}

my $filename = $ARGV[0];
my $time_since_last_doctor_created = 0; 
while(1){
    my @ps_info = @{get_ps_info()}; 
    my $value = check_if_other_doctor_is_alive(\@ps_info,"perl ./LogDoctor1.pl $filename","perl LogDoctor1.pl $filename"); 
    if ($value == 0 && (time - $time_since_last_doctor_created) > 3600){
        system("./LogDoctor1.pl $filename &");
        $time_since_last_doctor_created = time;
        printf STDERR "%s: LogDoctor2 is creating an instance of LogDoctor1 \n",scalar(localtime);
    }
    sleep(30);
}
1;