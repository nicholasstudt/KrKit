use 5.006001;
use ExtUtils::MakeMaker;
#use mod_perl2;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME			=> 'KrKit',
    VERSION_FROM	=> 'lib/KrKit.pm', # finds $VERSION
    PREREQ_PM		=> 	{
							'DBI' 				=> '0',
							'Date::Calc' 		=> '0',
							'Net::SMTP' 		=> '0',
							'Apache2::Request'	=> '0',
							"mod_perl2"			=> "0"
						}, # e.g., Module::Name => 1.1

    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/KrKit.pm', # retrieve abstract from module
       AUTHOR         => 'Nicholas Studt <nicholas@photodwarf.org>') : ()),
);
