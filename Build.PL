use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'KrKit',
    license             => 'perl',
    dist_author         => 'Nicholas Studt <nicholas@nicholasstudt.com>',
    dist_version_from   => 'lib/KrKit.pm',
    requires			=> {
							'Apache2::Request'	=> 0,
							'Date::Calc'		=> 0,
							'Net::SMTP'			=> 0,
							'DBI' 				=> '0',
						},
	recommends			=> {
							'DBD::Pg'			=> 0,
						},
    add_to_cleanup      => [ '_build', 'Build' ],
);

$builder->create_build_script();

