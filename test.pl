#!/usr/local/bin/perl -w
#
# evap - essentially identical to the C version of sample!

use lib '.';
use Getopt::EvaP;		# Evaluate Parameters

@PDT = split /\n/, <<'end-of-PDT';
PDT sample
  verbose, v: switch
  command, c: string = D_SAMPLE_COMMAND, "ps -el"
  scale_factor, sf: real = 1.2340896e-1
  millisecond_update_interval, mui: integer = $required
  ignore_output_file_column_one, iofco: boolean = TRUE
  output, o: file = stdout
  queue, q: key plotter, postscript, text, printer, keyend = printer
  destination, d: application = `hostname`
  tty, t: list of name = ("/dev/console", "/dev/tty0", "/dev/tty1")
PDTEND optional_file_list
end-of-PDT

@MM = split /\n/, <<'end-of-MM';
sample

	A sample program demonstrating typical Evaluate Parameters
	usage.

	Examples:

	  sample
	  sample -usage_help
	  sample -h
	  sample -full_help
          sample -mui 1234
.verbose
        A 'switch' type parameter emulates a typical standalone
        switch. If the switch is specified Evaluate Parameters
        returns a '1'.
.command
        A 'string' type parameter is just a list of characters,
        which must be quoted if it contains whitespace. 
        NOTE:  for this parameter you can also create and
        initialize the environment variable D_SAMPLE_COMMAND to
        override the standard default value for this command
        line parameter.  All types except 'switch' may have a
        default environment variable for easy user customization.
.scale_factor
        A 'real' type parameter must be a real number that may
        contain a leading sign, a decimal point and an exponent.
.millisecond_update_interval
        An 'integer' type parameter must consist of all digits
        with an optional leading sign.  NOTE: this parameter's
        default value is '$required', meaning that
        Evaluate Parameters ensures that this parameter is
        specified and given a valid value.  All types except
        'switch' may have a default value of '$required'.
.ignore_output_file_column_one
        A 'boolean' type parameter may be TRUE/YES/ON/1 or
        FALSE/NO/OFF/0, either upper or lower case.  If TRUE,
        Evaluate Parameters returns a value of '1', else '0'.
.output
        A 'file' type parameter expects a filename.  For Unix
        $HOME and ~ are expanded.  For evap/Perl 'stdin' and
	'stdout' are converted to '-' and '>-' so they can be
	used in a Perl 'open' function.
.queue
        A 'key' type parameter enumerates valid values.  Only the
        specified keywords can be entered on the command line.
.destination
	An 'application' type parameter is not type-checked in
	any - the treatment of this type of parameter is
	application specific.  NOTE:  this parameter' default
	value is enclosed in grave accents (or "backticks").
	Evaluate Parameters executes the command and uses it's
	standard output as the default value for the parameter.
.tty
	A 'name' type parameter is similar to a string except
	that embedded white-space is not allowed.  NOTE: this
	parameter is also a LIST, meaning that it can be
	specified multiple times and that each value is pushed
        onto a Perl LIST variable.  In general you should quote
        all list elements.  All types except 'switch' may be
	'list of'.
end-of-MM

EvaP \@PDT, \@MM, \%OPT;		# evaluate parameters

print "\nProgram name:\n  $OPT{help}\n\n";

print "verbose = $OPT{verbose}\n" if defined $OPT{verbose};
print "command = \"$OPT{command}\"\n";
print "scale_factor  = $OPT{scale_factor}\n";
print "millisecond_update_interval = $OPT{millisecond_update_interval}\n";
print "ignore_output_file_column_one = $OPT{ignore_output_file_column_one}\n";
print "output = $OPT{output}\n";
print "queue = $OPT{queue}\n";
print "destination = $OPT{destination}\n";
print "'list of' tty = \"", join('", "', @{$OPT{tty}}), "\"\n";

print "\nFile names:\n  ", join(' ', @ARGV), "\n" if @ARGV;
