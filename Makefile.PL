use ExtUtils::MakeMaker;
use Config;

open(M, '>Makefile') or die $!;
print M <<"END";
all:
	\@echo "Now make test and make install"

install::
	cp Getopt/EvaP.pm $Config{installprivlib}/Getopt/EvaP.pm
	cp man/EvaP.pm.3 $Config{installman3dir}/Getopt::EvaP.pm.3
	cp man/evap.3 $Config{installman3dir}/Getopt::evap.3

test:
	-test.pl
END
