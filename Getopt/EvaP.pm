$Getopt::EvaP::VERSION = '2.3.0';
$Getopt::EvaP::VERSION = $Getopt::EvaP::VERSION; # -w

package Getopt::EvaP; 

# EvaP.pm - Evaluate Parameters 2.3.0 for Perl (the getopt et.al. replacement)
#
# lusol@lehigh.EDU, 94/10/28
#
# Made to conform, as much as possible, to the C function evap. The C, Perl
# and Tcl versions of evap are patterned after the Control Data procedure
# CLP$EVALUATE_PARAMETERS for the NOS/VE operating system, although none
# approach the richness of CDC's implementation.
#
# Availability is via anonymous FTP from ftp.Lehigh.EDU (128.180.1.4) in the
# directory pub/evap/evap-2.x.
#
# Stephen O. Lidie, Lehigh University Computing Center.
#
# Copyright (C) 1993 - 1996 by Stephen O. Lidie.  All rights reserved.
#
# For related information see the evap/C header file evap.h.  Complete
# help can be found in the man pages evap(2), evap.c(2), EvaP.pm(2), 
# evap.tcl(2) and evap_pac(2).
#     
# 
#                           Revision History 
#
# lusol@Lehigh.EDU 94/10/28 (PDT version 2.0)  Version 2.2
#   . Original release - derived from evap.pl version 2.1.
#   . Undef option values for subsequent embedded calls.
#
# lusol@Lehigh.EDU 95/10/27 (PDT version 2.0)  Version 2.3.0
#   . Be a strict as possible.
#   . Revert to -h alias rather than -?.  (-? -?? -??? still available.)
#   . Move into Getopt class.
#   . Format for 80 columns (mostly).
#   . Optional third argument on EvaP call can be a reference to your own
#     %Options hash.  If specified, the variabes %Options, %options and 
#     $opt* are not used.

require 5.002;
use English; 
use subs qw(evap_fin evap_PDT_error evap_set_value evap_setup_for_evap);
use strict qw(refs subs);
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(EvaP EvaP_PAC);
@EXPORT_OK = qw(evap evap_pac);

*EvaP = \&evap;			# new alias for good 'ol Evaluate Parameters
*EvaP_PAC = \&evap_pac;		# new alias for Process Application Commands

sub evap {			# Parameter Description Table, Message Module
    
    my($ref_PDT, $ref_MM, $ref_Opt) = @ARG;
    
    $evap_DOS = 0 unless defined $evap_DOS; # 1 iff MS-DOS, else Unix
    $message_modules = "./libevapmm.a";

    local($pdt_reg_exp1) = '^(.)(.)(.?)$';
    local($pdt_reg_exp2) = '^TRUE$|^YES$|^ON$|^1$';
    local($pdt_reg_exp3) = '^FALSE$|^NO$|^OFF$|^0$';
    local($pdt_reg_exp4) = '^\s*no_file_list\s*$';
    local($pdt_reg_exp5) = '^\s*optional_file_list\s*$';
    local($pdt_reg_exp6) = '^\s*required_file_list\s*$';
    local($full_help) = 0;
    local($usage_help) = 0;
    local($file_list) = 'optional_file_list';
    local($error) = 0;
    local($pkg) = (caller)[0];
    local($value, $rt, $type, $required, @P_PARAMETER, %P_INFO, %P_ALIAS,
	  @P_REQUIRED, %P_VALID_VALUES, %P_ENV);
    local($option, $default_value, $list, $parameter, $alias, @keys, 
	  $found, $length, %P_EVALUATE, %P_DEFAULT_VALUE);
    local(@local_pdt);
    local($lref_MM) = $ref_MM;	# maintain a local reference
    local($lref_Opt) = $ref_Opt;
    
    $evap_embed = 0 unless defined $evap_embed; # 1 iff embed evap
    if ($evap_embed) {		# initialize for a new call
	if (defined $lref_Opt) {
	    undef %$lref_Opt;
	} else {
	    no strict 'refs';
	    undef %{"${pkg}::Options"};
	    undef %{"${pkg}::options"};
	}
    }
    
    # Verify correctness of the PDT.  Check for duplicate parameter names and
    # aliases.  Extract default values and possible keywords.  Decode the user
    # syntax and convert into a simpler form (ala NGetOpt) for internal use. 
    # Handle 'file list' too.

    @local_pdt = @{$ref_PDT};   # private copy of the PDT
    unshift @local_pdt, 'help, h: switch'; # supply -help automatically
    @P_PARAMETER = ();		# no parameter names
    %P_INFO = ();		# no encoded parameter information
    %P_ALIAS = ();		# no aliases
    @P_REQUIRED = ();		# no required parameters
    %P_VALID_VALUES = ();	# no keywords
    %P_ENV = ();		# no default environment variables
    %P_EVALUATE = ();		# no PDT values evaluated yet
    %P_DEFAULT_VALUE = ();	# no default values yet

  OPTIONS:
    foreach $option (@local_pdt) {

	$option =~ s/\s*$//;	# trim trailing spaces
	next OPTIONS if $option =~ /^#.*|PDT\s+|pdt\s+|PDT$|pdt$/;
	$option =~ s/\s*PDTEND|\s*pdtend//;
	next OPTIONS if $option =~ /^ ?$/;
	
	if ($option =~ /$pdt_reg_exp4|$pdt_reg_exp5|$pdt_reg_exp6/) {
	    $file_list = $option; # remember user specified file_list
	    next OPTIONS;
	}
	
        ($parameter, $alias, $ARG) = 
	  ($option =~ /^\s*(\S*)\s*,\s*(\S*)\s*:\s*(.*)$/);
	evap_PDT_error "Error in an Evaluate Parameters 'parameter, alias: " .
	    "type' option specification:  \"$option\".\n"
	    unless defined $parameter and defined $alias and defined $ARG;
	evap_PDT_error "Duplicate parameter $parameter:  \"$option\".\n" 
            if defined( $P_INFO{$parameter});
	push @P_PARAMETER, $parameter; # update the ordered list of parameters

	if (/(\bswitch\b|\binteger\b|\bstring\b|\breal\b|\bfile\b|\bboolean\b|\bkey\b|\bname\b|\bapplication\b)/) {
	    ($list, $type, $ARG) = ($PREMATCH, $1, $POSTMATCH);
	} else {
	    evap_PDT_error "Parameter $parameter has an undefined type:  " .
                "\"$option\".\n";
	}
	evap_PDT_error "Expecting 'list of', found:  \"$list\".\n" 
            if $list ne '' and $list !~ /\s*list\s+of\s+/;
        $list = '1' if $list;	# list state = 1, possible default PDT values
        $type = 'w' if $type =~ /^switch$/;
	$type = substr $type, 0, 1;

        ($ARG, $default_value) = /\s*=\s*/ ? ($PREMATCH, $POSTMATCH) : 
            ('', ''); # get possible default value
	if ($default_value =~ /^([^\(]{1})(\w*)\s*,\s*(.*)/) { 
            # If environment variable AND not a list.
	    $default_value = $3;
	    $P_ENV{$parameter} = $1 . $2;
	}
        $required = ($default_value eq '$required') ? 'R' : 'O';
        $P_INFO{$parameter} = defined $type ? $required . $type . $list : "";
	push @P_REQUIRED, $parameter if $required =~ /^R$/;

        if ($type =~ /^k$/) {
	    $ARG =~ s/,/ /g;
	    @keys = split ' ';
	    pop @keys;		# remove 'keyend'
	    $P_VALID_VALUES{$parameter} = join ' ', @keys;
        } # ifend keyword type
	
	foreach $value (keys %P_ALIAS) {
	    evap_PDT_error "Duplicate alias $alias:  \"$option\".\n" 
                if $alias eq $P_ALIAS{$value};
	}
	$P_ALIAS{$parameter} = $alias; # remember alias

	evap_PDT_error "Cannot have 'list of switch':  \"$option\".\n" 
            if $P_INFO{$parameter} =~ /^.w1$/;

        if ($default_value ne '' and $default_value ne '$required') {
	    $default_value = $ENV{$P_ENV{$parameter}} if $P_ENV{$parameter} 
                and $ENV{$P_ENV{$parameter}};
	    $P_DEFAULT_VALUE{$parameter} = $default_value;
            evap_set_value 0,  $type, $list, $default_value, $parameter;
	} elsif ($evap_embed) {
	    no strict 'refs';
	    undef ${"${pkg}::opt_${parameter}"} if not defined $lref_Opt;
        }
	
    } # forend OPTIONS

    if ($error) {
        print STDERR "Read the `man' page \"EvaP.pm\" for details on PDT " .
            "syntax.\n";
        exit 1;
    }

    # Process arguments from the command line, stopping at the first parameter
    # without a leading dash, or a --.  Convert a parameter alias into its full
    # form, type-check parameter values and store the value into global 
    # variables for use by the caller.  When complete call evap_fin to 
    # perform final processing.
    
  ARGUMENTS:
    while ($#ARGV >= 0) {
	
	$option = shift @ARGV;	# get next command line parameter
	$value = undef;		# assume no value
	
	$full_help = 1 if $option =~ /^-(full_help|\Q???\E)$/;
	$usage_help = 1 if $option =~ /^-(usage_help|\Q??\E)$/;
	$option = '-help' if $full_help or $usage_help or
	    $option  =~ /^-(\Q?\E)$/;
	
	if ($option =~ /^(--|-)/) { # check for end of parameters
	    if ($option eq '--') {
		return evap_fin;
	    }
	    $option = $POSTMATCH;	# option name without dash
	} else {		# not an option, push it back on the list
	    unshift @ARGV, $option;
	    return evap_fin;
	}
	
	foreach $alias (keys %P_ALIAS) { # replace alias with the full spelling
	    $option = $alias if $option eq $P_ALIAS{$alias};
	}
	
	if (not defined($rt = $P_INFO{$option})) {
	    $found = 0;
	    $length = length $option;
	    foreach $key (keys %P_INFO) { # try substring match
		if ($option eq substr $key, 0, $length) {
		    if ($found) {
			print STDERR "Ambiguous parameter: -$option.\n";
			$error++;
			last;
		    }
		    $found = $key; # remember full spelling
		}
	    } # forend
	    $option = $found ? $found : $option;
	    if (not defined($rt = $P_INFO{$option})) {
		print STDERR "Invalid parameter: -$option.\n";
		$error++;
		next ARGUMENTS;
	    }
	} # ifend non-substring match
	
	($required, $type, $list) = ($rt =~ /$pdt_reg_exp1/);
	
	if ($type !~ /^w$/) {
	    if ($#ARGV < 0) { # if argument list is exhausted
		print STDERR "Value required for parameter -$option.\n";
		$error++;
		next ARGUMENTS;
	    } else {
		$value = shift @ARGV;
	    }
	}
	
	if ($type =~ /^w$/) {	# switch
	    $value = 1;
	} elsif ($type =~ /^i$/) { # integer
	    if ($value !~ /^[+-]?[0-9]+$/)  {
		print STDERR "Expecting integer reference, found \"$value\" " .
                    "for parameter -$option.\n";
		$error++;
		undef $value;
	    }
	} elsif ($type =~ /^r$/) { # real number, int is also ok
	    if ($value !~ /^\s*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?\s*$/) {
		print STDERR "Expecting real reference, found \"$value\" " .
                    "for parameter -$option.\n";
		$error++;
		undef $value;
	    }
	} elsif ($type =~ /^s$|^n$|^a$/) { # string or name or application
	} elsif ($type =~ /^f$/) { # file
	    if (length $value > 255) {
		print STDERR "Expecting file reference, found \"$value\" " .
                    "for parameter -$option.\n";
		$error++;
		undef $value;
	    }
	} elsif ($type =~ /^b$/) { # boolean
	    $value =~ tr/a-z/A-Z/;
	    if ($value !~ /$pdt_reg_exp2|$pdt_reg_exp3/i) {
		print STDERR "Expecting boolean reference, found " .
                    "\"$value\" for parameter -$option.\n";
		$error++;
		undef $value;
            }
	} elsif ($type =~ /^k$/) { # keyword

	    # First try exact match, then substring match.

	    undef $found;
	    @keys = split ' ', $P_VALID_VALUES{$option};
	    for ($i = 0; $i <= $#keys and not defined $found; $i++) {
		$found = 1 if $value eq $keys[$i];
	    }
	    if (not defined $found) { # try substring match
		$length = length $value;
		for ($i = 0; $i <= $#keys; $i++) {
		    if ($value eq substr $keys[$i], 0, $length) {
			if (defined $found) {
			    print STDERR "Ambiguous keyword for parameter " .
                                "-$option: $value.\n";
			    $error++;
			    last; # for
			}
			$found = $keys[$i]; # remember full spelling
		    }
		} # forend
		$value = defined( $found ) ? $found : $value;
	    } # ifend
	    if (not defined $found) {
		print STDERR "\"$value\" is not a valid value for the " .
                    "parameter -$option.\n";
		$error++;
		undef $value;
	    }
	} # ifend type-check
	
	next ARGUMENTS if not defined $value;
	    
    	$list = '2' if $list =~ /^1$/; # advance list state
	evap_set_value 1,  $type, $list, $value, $option if defined $value;
	# Remove from $required list if specified.
	@P_REQUIRED = grep $option ne $ARG, @P_REQUIRED;
	$P_INFO{$option} = $required . $type . '3' if $list;

    } # whilend ARGUMENTS
    
    return evap_fin;
    
} # end evap

sub evap_fin {

    # Finish up Evaluate Parameters processing:
    #
    # If -usage_help, -help or -full_help was requested then do it and exit.
    # Else,
    #   
    #  . Store program name in `help' variables.
    #  . Perform deferred evaluations.
    #  . Ensure all $required parameters have been given a value.
    #  . Ensure the validity of the trailing file list.
    #  . Exit with a Unix return code of 1 if there were errors and 
    #    $evap_embed = 0, else return to the calling Perl program with a 
    #    proper return code.
    
    use File::Basename;
    
    my($m, $p, $required, $type, $list, $def, $rt, $def, $element, $is_string,
       $pager, $do_page);

    # Define Help Hooks text as required.
    
    $evap_Help_Hooks{'P_HHURFL'} = " file(s)\n" 
        if not defined $evap_Help_Hooks{'P_HHURFL'};
    $evap_Help_Hooks{'P_HHUOFL'} = " [file(s)]\n"
        if not defined $evap_Help_Hooks{'P_HHUOFL'};
    $evap_Help_Hooks{'P_HHUNFL'} = "\n"
        if not defined $evap_Help_Hooks{'P_HHUNFL'};
    $evap_Help_Hooks{'P_HHBRFL'} = "\nfile(s) required by this command\n\n"
        if not defined $evap_Help_Hooks{'P_HHBRFL'};
    $evap_Help_Hooks{'P_HHBOFL'} = "\n[file(s)] optionally required by this command\n\n"
        if not defined $evap_Help_Hooks{'P_HHBOFL'};
    $evap_Help_Hooks{'P_HHBNFL'} = "\n"
        if not defined $evap_Help_Hooks{'P_HHBNFL'};
    $evap_Help_Hooks{'P_HHERFL'} = "Trailing file name(s) required.\n"
        if not defined $evap_Help_Hooks{'P_HHERFL'};
    $evap_Help_Hooks{'P_HHENFL'} = "Trailing file name(s) not permitted.\n"
        if not defined $evap_Help_Hooks{'P_HHENFL'};

    my $want_help = 0;
    if (defined $lref_Opt) {
	$want_help = $lref_Opt->{'help'};
    } else {
	no strict 'refs';
	$want_help = "${pkg}::opt_help";
	$want_help = $$want_help;
    }

    if ($want_help) {		# see if help was requested
	
	my($optional);
	my(%parameter_help) = ();
	my($parameter_help_in_progress) = 0;
	my(%type_list) = (
	    'w' => 'switch',
	    'i' => 'integer',
	    's' => 'string',
	    'r' => 'real',
	    'f' => 'file',
	    'b' => 'boolean',
	    'k' => 'key',
	    'n' => 'name',
	    'a' => 'application',
	);

	# Establish the pager and open the pipeline.  Do no paging if the 
	# boolean environment variable D_EVAP_DO_PAGE is FALSE.

	$pager = 'more';
	$pager = $ENV{'PAGER'} if defined $ENV{'PAGER'} and $ENV{'PAGER'};
	$pager = $ENV{'MANPAGER'} if defined $ENV{'MANPAGER'} and 
	    $ENV{'MANPAGER'};
	$pager = '|' . $pager;
	if (defined $ENV{'D_EVAP_DO_PAGE'} and 
	    (($do_page = $ENV{'D_EVAP_DO_PAGE'}) ne '')) {
	    $do_page =~ tr/a-z/A-Z/;
	    $pager = '>-' if $do_page =~ /$pdt_reg_exp3/;
	}
	open PAGER, "$pager";
	
	print PAGER "Command Source:  $PROGRAM_NAME\n\n\n\n" if $full_help;

	# Print the Message Module text and save any full help.  The key is the
	# parameter name and the value is a list of strings with the newline as
	# a separator.  If there is no Message Module or it's empty then 
	# display an abbreviated usage message.
	
        if ($usage_help or not defined @{$lref_MM} or $#{$lref_MM} < 0) {
	    
	    $basename = basename($PROGRAM_NAME, "");
	    print PAGER "\nUsage: ", $basename;
	    $optional = '';
	    foreach $p (@P_PARAMETER) {
		if ($P_INFO{$p} =~ /^R..?$/) { # if $required
		    print PAGER " -$P_ALIAS{$p}";
		} else {
		    $optional .= " -$P_ALIAS{$p}";
		}
	    } # forend
	    print PAGER " [$optional]" if $optional;
	    if ($file_list =~ /$pdt_reg_exp5/) {
		print PAGER "$evap_Help_Hooks{'P_HHUOFL'}";
	    } elsif ($file_list =~ /$pdt_reg_exp6/) {
		print PAGER "$evap_Help_Hooks{'P_HHURFL'}";
	    } else {
		print PAGER "$evap_Help_Hooks{'P_HHUNFL'}";
	    }
	    
        } else {
	    
	  MESSAGE_LINE:
	    foreach $m (@{$lref_MM}) {
		
		if ($m =~ /^\.(.*)$/) { # look for 'dot' leadin character
		    $p = $1; # full spelling of parameter
		    $parameter_help_in_progress = 1;
		    $parameter_help{$p} = "\n";
		    next MESSAGE_LINE;
		} # ifend start of help text for a new parameter
		if ($parameter_help_in_progress) { 
		    $parameter_help{$p} .=  $m . "\n";
		} else {
		    print PAGER $m, "\n";
		}
		
	    } # forend MESSAGE_LINE
	    
	} # ifend usage_help

	# Pass through the PDT list printing a standard evap help summary.

        print PAGER "\nParameters:\n";
	if (not $full_help) {print PAGER "\n";}
	
      ALL_PARAMETERS:
        foreach $p (@P_PARAMETER) {

	    no strict 'refs';
	    if ($full_help) {print PAGER "\n";}
	    
	    if ($p =~ /^help$/) {
		print PAGER "-$p, $P_ALIAS{$p}, usage_help, full_help: Display Command Information\n";
                if ($full_help) {
         	    print PAGER <<"end_of_DISCI";
\n\tDisplay information about this command, which includes
\ta command description with examples, plus a synopsis of
\tthe command line parameters.  If you specify -full_help
\trather than -help complete parameter help is displayed
\tif it's available.
end_of_DISCI
	        }
		next ALL_PARAMETERS;
	    }
	    
	    $rt = $P_INFO{$p};	# get encoded required/type information
	    ($required, $type, $list) = ($rt =~ /$pdt_reg_exp1/); # unpack
	    $type = $type_list{$type};
	    $is_string = ($type =~ /^string$/);
	    
	    print PAGER "-$p, $P_ALIAS{$p}: ", $list ? 'list of ' : '', $type; 
	    
	    print PAGER " ", join(', ', split(' ', $P_VALID_VALUES{$p})), 
                ", keyend" if $type =~ /^key$/;
	    
	    my($ref);
            if (defined $lref_Opt) {
                $ref = \$lref_Opt->{$p};
                $ref = \@{$lref_Opt->{$p}} if $list;
            } else {
                $ref = "${pkg}::opt_${p}";
            }
	    if ($list) {
                $def = defined @{$ref} ? 1 : 0;
	    } else {
                $def = defined ${$ref} ? 1 : 0;
            }
    
	    if ($required =~ /^O$/ or $def == 1) { # if $optional or defined
		
                if ($def == 0) { # undefined and $optional
    		    print PAGER "\n";
                } else {	# defined (either $optional or $required), display the default value(s)
                    if ($list) {
			print PAGER $P_ENV{$p} ? " = $P_ENV{$p}, " : " = ";
			print PAGER $is_string ? "(\"" : "(", $is_string ? join('", "', @{$ref}) : join(', ', @{$ref}),
			      $is_string ? "\")\n" : ")\n";
                    } else {	# not 'list of'
			print PAGER $P_ENV{$p} ? " = $P_ENV{$p}, " : " = ";
			print PAGER $is_string ? "\"" : "", ${$ref}, $is_string ? "\"\n" : "\n";
                    } # ifend 'list of'
                } # ifend
		
	    } elsif ($required =~ /R/) {
		print PAGER $P_ENV{$p} ? " = $P_ENV{$p}, " : " = ";
		print PAGER "\$required\n";
	    } else {
		print PAGER "\n";
	    } # ifend $optional or defined parameter
	    
            if ($full_help) {
		if (defined $parameter_help{$p}) {
		    print PAGER "$parameter_help{$p}";
		} else {
		    print PAGER "\n";
		}
	    }
	    
	} # forend ALL_PARAMETERS

	if ($file_list =~ /$pdt_reg_exp5/) {
	    print PAGER "$evap_Help_Hooks{'P_HHBOFL'}";
	} elsif ($file_list =~ /$pdt_reg_exp6/) {
	    print PAGER "$evap_Help_Hooks{'P_HHBRFL'}";
	} else {
	    print PAGER "$evap_Help_Hooks{'P_HHBNFL'}";
	}

	close PAGER;
	if ($evap_embed) {
	    return -1;
	} else {
	    exit 0;
	}
	
    } # ifend help requested

    # Evaluate remaining unspecified command line parameters.  This has been
    # deferred until now so that if -help was requested the user sees 
    # unevaluated boolean, file and backticked values.

    foreach $parameter (@P_PARAMETER) {
	if (not $P_EVALUATE{$parameter} and $P_DEFAULT_VALUE{$parameter}) {
	    ($required, $type, $list) = ($P_INFO{$parameter} =~ /$pdt_reg_exp1/);
	    if ($type ne 'w') {
		$list = 2 if $list; # force re-initialization of the list
		evap_set_value 1, $type, $list, $P_DEFAULT_VALUE{$parameter}, $parameter;
	    } # ifend non-switch
	} # ifend not specified
    } # forend all PDT parameters

    # Store program name for caller.

    evap_set_value 0,  'w', '', $PROGRAM_NAME, 'help';
    
    # Ensure all $required parameters have been specified on the command line.

    foreach $p (@P_REQUIRED) {
	print STDERR "Parameter $p is required but was omitted.\n";
	$error++;
    } # forend
    
    # Ensure any required files follow, or none do if that is the case.

    if ($file_list =~ /$pdt_reg_exp4/ and $#ARGV > 0 - 1) {
        print STDERR "$evap_Help_Hooks{'P_HHENFL'}";
        $error++;
    } elsif ($file_list =~ /$pdt_reg_exp6/ and $#ARGV == 0 - 1) {
        print STDERR "$evap_Help_Hooks{'P_HHERFL'}";
        $error++;
    }
    
    print STDERR "Type $PROGRAM_NAME -h for command line parameter " .
        "information.\n" if $error;

    exit 1 if $error and not $evap_embed;
    if (not $error) {
	return 1;
    } else {
	return 0;
    }
    
} # end evap_fin

sub evap_PDT_error {

    # Inform the application developer that they've screwed up!

    my($msg) = @ARG;

    print STDERR "$msg";
    $error++;
    next OPTIONS;

} # end evap_PDT_error

sub evap_set_value {
    
    # Store a parameter's value; some parameter types require special type 
    # conversion.  Store values the old way in scalar/list variables of the 
    # form $opt_parameter and @opt_parameter, as well as the new way in hashes
    # named %options and %Options.  'list of' parameters are returned as a 
    # reference in %options/%Options (a simple list in @opt_parameter).  Or,
    # just stuff them in a user hash, is specified.
    #
    # Evaluate items in grave accents (backticks), boolean and files if 
    # `evaluate' is TRUE.
    #
    # Handle list syntax (item1, item2, ...) for 'list of' types.
    #
    # Lists are a little weird as they may already have default values from the
    # PDT declaration. The first time a list parameter is specified on the 
    # command line we must first empty the list of its default values.  The 
    # P_INFO list flag thus can be in one of three states: 1 = the list has 
    # possible default values from the PDT, 2 = first time for this command 
    # line parameter so empty the list and THEN push the parameter's value, and
    # 3 = just keep pushing new command line values on the list.

    my($evaluate, $type, $list, $v, $hash_index) = @ARG;
    my($option, $hash1, $hash2) = ("${pkg}::opt_${hash_index}", 
				   "${pkg}::options", "${pkg}::Options");
    my($value, @values);

    if ($list =~ /^2$/) {	# empty list of default values
	if (defined $lref_Opt) {
	    $lref_Opt->{$hash_index} = [];
	} else {
	    no strict 'refs';
	    @{$option} = ();
	    $hash1->{$hash_index} = \@{$option};
	    $hash2->{$hash_index} = \@{$option};
	}
    }

    if ($list and $v =~ /^\(+.*\)+$/) { # check for list
	@values = eval "$v"; # let Perl do the walking
    } else {
	$v =~ s/["|'](.*)["|']/$1/; # remove any bounding superfluous quotes
	@values = $v;		# a simple scalar	
    } # ifend initialize list of values

    foreach $value (@values) {

        if ($evaluate) {
            $P_EVALUATE{$hash_index} = 'evaluated';
            $value =~ /^(`*)([^`]*)(`*)$/; # check for backticks
	    chop($value = `$2`) if $1 eq '`' and $3 eq '`';
	    if (not $evap_DOS and $type =~ /^f$/) {
                my(@path) = split /\//, $value;
	        if ($value =~ /^stdin$/) {
                    $value = '-';
                } elsif ($value =~ /^stdout$/) {
                    $value = '>-';
                } elsif ($path[0] =~ /(^~$|^\$HOME$)/) {
		    $path[0] = $ENV{'HOME'};
                    $value = join '/', @path;
                }
            } # ifend file type

            if ($type =~ /^b$/) {
	        $value = '1' if $value =~ /$pdt_reg_exp2/i;
	        $value = '0' if $value =~ /$pdt_reg_exp3/i;
            } # ifend boolean type
        } # ifend evaluate

        if ($list) {		# extend list with new value
            if (defined $lref_Opt) {
                push @{$lref_Opt->{$hash_index}}, $value;
            } else {
                no strict 'refs';
	        push @{$option}, $value;
                $hash1->{$hash_index} = \@{$option};
                $hash2->{$hash_index} = \@{$option};
            }
        } else {		# store scalar value
            if (defined $lref_Opt) {
                $lref_Opt->{$hash_index} = $value;
            } else {
                no strict 'refs';
	        ${$option} = $value;
                $hash1->{$hash_index} = $value;
                $hash2->{$hash_index} = $value;
                # ${$hash2}{$hash_index} = $value; EQUIVALENT !
            }
        }

    } # forend
	
} # end evap_set_value

sub evap_pac {

    # Process Application Commands - an application command can be envoked by 
    # entering either its full spelling or the alias.

    my($prompt, $I, %cmds) = @ARG;

    my($proc, $args, %long, %alias, $name, $long, $alias);
    my $pkg = (caller)[0];
    my $inp = ref($I) ? $I : "${pkg}::${I}";

    require "shellwords.pl";

    $evap_embed = 1;		# enable embedding
    $shell = (defined $ENV{'SHELL'} and $ENV{'SHELL'} ne '') ? 
        $ENV{'SHELL'} : '/bin/sh';
    foreach $name (keys %cmds) {
	$cmds{$name} = $pkg . '::' . $cmds{$name}; # qualify
    }
    $cmds{'display_application_commands|disac'} = 'evap_disac_proc(%cmds)';
    $cmds{'!'} = 'evap_bang_proc';

    # First, create new hash variables with full/alias names.

    foreach $name (keys %cmds) {
        if ($name =~ /\|/) {
            ($long, $alias) = ($name =~ /(.*)\|(.*)/);
	    $long{$long} = $cmds{$name};
	    $alias{$alias} = $cmds{$name};
        } else {
	    $long{$name} = $cmds{$name};
	}
    }

    print STDOUT "$prompt";

    no strict 'refs';
  GET_USER_INPUT:
    while (<$inp>) {

	next GET_USER_INPUT if /^\s*$/;	# ignore empty input lines

	if (/^\s*!(.+)/) {
	    $ARG = '! ' . $1;
	}

        ($PROGRAM_NAME, $args) = /\s*(\S+)\s*(.*)/;
	if (defined $long{$PROGRAM_NAME}) {
	    $proc = $long{$PROGRAM_NAME};
	} elsif (defined $alias{$PROGRAM_NAME}) {
	    $proc = $alias{$PROGRAM_NAME};
	} else  {
            print STDERR <<"end_of_ERROR";
Error - unknown command `$PROGRAM_NAME'.  Type `disac -do f' for a
list of valid application commands.  You can then ...\n
Type `xyzzy -h' for help on application command `xyzzy'.
end_of_ERROR
	    next GET_USER_INPUT;
        }

	if ($PROGRAM_NAME eq '!') {
	    @ARGV = $args;
	} else {
	    @ARGV = &shellwords($args);
	}

        eval "&$proc;";		# call the evap/user procedure
	print STDERR $EVAL_ERROR if $EVAL_ERROR;

    } # whilend GET_USER_INPUT
    continue { # while GET_USER_INPUT
        print STDOUT "$prompt";
    } # continuend
    print STDOUT "\n" unless $prompt eq "";

} # end evap_pac

sub evap_bang_proc {
    
    # Issue commands to the user's shell.  If the SHELL environment variable is
    # not defined or is empty, then /bin/sh is used.

    my $cmd = $ARGV[0];

    if ($cmd ne '') {
	evap_setup_for_evap 'bang' unless defined @bang_proc_PDT;
	$evap_Help_Hooks{'P_HHUOFL'} = " Command(s)\n";
	$evap_Help_Hooks{'P_HHBOFL'} = "\nA list of shell Commands.\n\n";
	my $junk = \@bang_proc_MM; # supress -w warning
	if (EvaP(\@bang_proc_PDT, \@bang_proc_MM) != 1) {return;}
	system "$shell -c '$cmd'";
    } else {
	print STDOUT "Starting a new `$shell' shell; use `exit' to return " .
	    "to this application.\n";
	system $shell;
    }

} # end evap_bang_proc

sub evap_disac_proc {
    
    # Display the list of legal application commands.

    my(%commands) = @ARG;
    my(@brief, @full, $name, $long, $alias);

    evap_setup_for_evap 'disac' unless defined @disac_proc_PDT;
    my $junk = \@disac_proc_MM;	# supress -w warning
    if (EvaP(\@disac_proc_PDT, \@disac_proc_MM) != 1) {return;}

    foreach $name (keys %commands) {
        if ($name =~ /\|/) {
            ($long, $alias) = ($name =~ /(.*)\|(.*)/);
        } else {
	    $long = $name;
            $alias = '';
	}
        push @brief, $long;
        push @full, ($alias ne '') ? "$long, $alias" : "$long";
    }

    open H, ">$Options{'output'}";
    if ($Options{'display_option'} eq 'full') {
        print H "\nFor help on any application command (or alias) use the -h switch.  For example,\n";
        print H "try `disac -h' for help on `display_application_commands'.\n";
        print H "\nCommand and alias list for this application:\n\n";
	print H "  ", join("\n  ", sort(@full)), "\n";
    } else {
        print H join("\n", sort(@brief)), "\n";
    }
    close H;

} # end evap_disac_proc

sub evap_setup_for_evap {
    
    # Initialize evap_pac's builtin commands' PDT/MM variables.

    my($command) = @ARG;

    open IN, "ar p $message_modules ${command}_pdt|";
    eval "\@${command}_proc_PDT = <IN>;";
    close IN;

    open IN, "ar p $message_modules ${command}.mm|";
    eval "\@${command}_proc_MM = grep \$@ = s/\n\$//, <IN>;";
    close IN;

} # end evap_setup_for_evap

1;
