
use strict; 
use warnings; 
use IDAS;


#This program is a program watcher that takes in a text file of programs to watch 
#sends out error emails if a program in the list stops running via ps checks
#creates a smaller program doctor2 that monitors doctor1 and reruns doctor1 in case of termination
#if doctor2 terminates the program will create a new one

#how to run the program
#./doctor1.pl textfile.txt &
#Text file formatting:
#have the watched files be in their ps -el -o pid,s,cmd formatting 
#example of textfile.txt 
# Max: 10
# Min: 10
# Process Email: ________________
# Email: __________________
# /path file
# Email: _______________________


# Process Email: notifies the user of when the server has a suspiciously high or low number of processes 
#                based on the Max or Min input. defaults to 500 and 10.
# Email: notifies the user if the process is not running or there is duplicates of it (based on if the string exists in ps)
#        all lines below email that are not specifically tagged will be added to the email's group of processes to watch


#takes in a subject (a string), 
#a body (an html formatted string as seen in report_generator), 
# and an email (a string ie "--------------") 


sub generateEmail {
   my $subject = $_[0];
   my $body = $_[1];
   my $contact = $_[2];
   printf STDERR "%s: Sending \"$subject\" to: $contact\n",scalar(localtime);
   #Requires use of IDAS which is a custom package in bc gov
   $IDAS->sendMail(
         Subject   =>    $subject,
         To        =>    $contact,
         From      =>    "iappsup\@gov.bc.ca",
         Body      =>    $body
         );
}

#Grabs currently running process info using ps -ef 
#gets PID and the program name from PS using RegEx Capture groups 
# ps -el -o pid,s,cmd
#  PID S COMMAND
#    0 T sched
#puts info into an array of 3 values PID, state, command
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

#checks a list for duplicates and returns the 
#list of duplicates in the file. 
sub duplicate_check {
    my $list = shift;
    my @list = @{$list};
    my %exists; 
    my %dupes;
    for my $element (@list){
        if( exists($exists{$element} ) ){
            $dupes{$element} = 'exists';
        }
        else{
            $exists{$element} = 'exists';
        }
    }
    my @duplicate_process_list = keys %dupes; 
    return @duplicate_process_list; 

}
# returns list of files are supposed to be running 
#and are found in the ps info 
sub check_if_running {
    my $processes = shift; 
    my @list_to_check = @{$processes};
    my $processes_running = shift; 
    my @processes_running = @{$processes_running}; 
    my @alive_processes;
    for my $check (@list_to_check){
        for my $process (@processes_running){
            if($check eq $process->[2]){
                push(@alive_processes,$check);
            }
        }
    }
    return @alive_processes;
}
#creates a string from a list in HTML formatting for use in ___
#changes the string into HTML formatting 
sub string_generator {
    my $list = shift;
    my @list = @{$list};
    my $return_string = "<h3>";
    for my $element (@list){
        $return_string = $return_string." ".$element.","; 
    } 
    $return_string = $return_string."</h3>";
    return $return_string;
}
#pass in the list of processes that should be running,
#what processes are running, and the duplicate processes running
#Generates the email to be send using ____ to the recipiant. 
sub report_generator {
    my $processes_to_inspect = $_[0];  
    my $running_processes = $_[1];
    my $duplicates = $_[2];
    my $To = $_[3];
    my @processes_to_inspect = @{$processes_to_inspect}; 
    my @running_processes = @{$running_processes};
    my @duplicates = @{$duplicates};
    my @not_running_processes; 
    for my $check (@processes_to_inspect){
        my $flag = 0; 
        for my $running (@running_processes){
            if($running eq $check){
                $flag = 1; 
            }
        }
        if ($flag == 0){
            push(@not_running_processes, $check);
        }
    }

    my $subject = "LogDoctor Error Report";
    my $header1 = "<h3>Processes Not Running</h3>"; 

    my $body1 = string_generator(\@not_running_processes); 

    my $header2 = "<h3>Duplicate Processes Running</h3>"; 
    my $body2 = string_generator(\@duplicates); 
    my $body = $header1.$body1.$header2.$body2;
    #if there are duplicates or processes not running then generate an error email
    if ((scalar(@duplicates) > 0) || (scalar(@not_running_processes) > 0)){
        generateEmail($subject,$body,$To); 
    }
}
#There are is another file called doctor2.pl 
#It has the job of keeping doctor1.pl alive 
#This function checks to make sure that it is running in the ps check
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

# sends an email out if the server has too high or low of processes running 
sub generate_error_email {
    my $string = shift; 
    my $subject = "Suspicious Levels of Processes Running on Server";
    my $header1 = "<h3>Number of Processes Running</h3>"; 
    my $header2 = "<h3>Duplicate Processes Running</h3>"; 
    my $body = "<h3>".$string."</h3>";
    my $To = shift;
    generateEmail($subject,$body,$To); 
}

my $min_process_count = 10;         ##################
my $max_process_count = 500;        # Default Values #
my $filename = $ARGV[0];            ##################
my %email_and_processes = ();
my %last_notified_running_processes_flag = ();
my $watch_process_email = 'none'; 
my $current_email = 'none';

open(FH,'<',"$filename") or die "could not file given to doctor1. was a file given?";
while(<FH>){
    my $line = $_; 
    chomp($line);
    if($line =~ /Max:\s*(\d*)/){                          #########################################
        $max_process_count = $1;                          # Reads in the file and sets the values #
    }                                                     #########################################
    elsif($line =~ /Min:\s*(\d*)/){                       
        $min_process_count = $1;                          
    } 
    elsif($line =~ /^Process Email:\s*(\S*)/){
        $watch_process_email = $1; 
    }
    elsif($line =~ /^Email:\s*(\S*)/){
        $current_email = $1; 
        $email_and_processes{$current_email} = []; 
        $last_notified_running_processes_flag{$current_email} = undef;
        
    }
    elsif($current_email ne 'none'){
        my @array = @{$email_and_processes{$current_email}};
        push(@array,$line);
        $email_and_processes{$current_email} = [@array]; 
    }
}
close FH; 

my $last_notified_process_size_flag = undef; 
my $time_since_last_doctor_created = 0; 

while(1){
    printf STDERR "%s: LogDoctor1 is starting up\n",scalar(localtime);  
    my $process_count = `ps -ef | wc -l`;                                                                        ##################################################
        if ( $process_count >= $max_process_count || $process_count <= $min_process_count){                      # Checks if the process count is too high or low # 
            if(!defined($last_notified_process_size_flag) || (time - $last_notified_process_size_flag) > 3600){  # generates email if outside of the bounds.      # 
               generate_error_email($process_count,$watch_process_email);                                        ##################################################
               $last_notified_process_size_flag = time; 
            }
        }

    my @ps_info = @{get_ps_info()};                                                  #########################################################
    for my $email (keys %email_and_processes){                                       # Loops through email_and_processes hash and checks     #
        my @processes_to_inspect = @{$email_and_processes{$email}};                  # if there are not running processes or duplicates and  #
        my @running_processes = check_if_running(\@processes_to_inspect,\@ps_info);  # emails the user.                                      # 
        my @duplicates = duplicate_check(\@running_processes);                       #########################################################
        if (!defined($last_notified_running_processes_flag{$email}) || (time - $last_notified_running_processes_flag{$email}) > 3600){
            report_generator(\@processes_to_inspect,\@running_processes,\@duplicates,$email); 
            $last_notified_running_processes_flag{$email} = time; 
        }
    }

    my $value = check_if_other_doctor_is_alive(\@ps_info,"perl ./LogDoctor2.pl $filename","perl LogDoctor2.pl $filename"); #########################################
    if ($value == 0 && (time - $time_since_last_doctor_created) > 3600){                                                   # Checks if doctor2 is running which    #
        system("./LogDoctor2.pl $filename &");                                                                             # monitors and can rerun doctor1 in the # 
        $time_since_last_doctor_created = time;                                                                            # case it terminates. Reruns doctor2 if #
        printf STDERR "%s: LogDoctor1 is creating an instance of LogDoctor2 \n",scalar(localtime);                         # the program isn't running             #
    }                                                                                                                      # the program isn't running             #
    sleep(30);                                                                                                             #########################################
}
1;