package KrKit::Control::Access;
######################################################################
# $Id: Access.pm,v 1.6 2005/08/26 21:52:42 nstudt Exp $
# $Date: 2005/08/26 21:52:42 $
######################################################################
use strict;

use Apache2::Const -compile => qw(:common);
use Apache2::Connection;
use Apache2::RequestUtil;

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	# Range, or specfic ips.
	my $remote_ip 	= $r->connection->remote_ip( );
	my $user 		= $r->dir_config( 'Access_AnonUser' ) || 'anonymous_ip';
	my $ranges 		= $r->dir_config( 'Access_Ranges' );
	my $ips 		= $r->dir_config( 'Access_Ips' );
	my $ignore 		= $r->dir_config( 'Access_NoOverRide' ) || 0;

	if ( defined $ranges ) {
		# make the decimal version of the ip.
		my $dip = sprintf( "%08b%08b%08b%08b", split( '\.', $remote_ip ) );

		for my $range ( split( ',', $ranges ) ) {
			
			my ( $ranged, $slash ) = $range =~ /^\s?(.*)\/(\d+)\s?$/;

			my $drng = sprintf( "%08b%08b%08b%08b", split( '\.', $ranged ) );

			if ( substr( $dip, 0, $slash ) eq substr( $drng, 0, $slash ) ) { 

				$r->user( $user ) if ( ! $r->user );
				
				if ( ! $ignore ) {
					$r->set_handlers( PerlAuthenHandler => [\&Apache2::Const::OK] );
					$r->set_handlers( PerlAuthzHandler 	=> [\&Apache2::Const::OK] );
				}

				return( Apache2::Const::OK );
			}
		}
	}

	if ( defined $ips ) {
		for my $ip ( split( ',', $ips ) ) {
			if ( $ip =~ /^\s?$remote_ip\s?$/ ) {
				
				$r->user( $user ) if ( ! $r->user );

				if ( ! $ignore ) {
					$r->set_handlers( PerlAuthenHandler => [\&Apache2::Const::OK] );
					$r->set_handlers( PerlAuthzHandler 	=> [\&Apache2::Const::OK] );
				}

				return( Apache2::Const::OK );
			}
		}
	}

	return( Apache2::Const::DECLINED ); 
} # END handler

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Access - IP based authentication.

=head1 SYNOPSIS 
 
  use KrKit::Control::Access;

=head1 DESCRIPTION

This module controls access to a resource based on ip address or ranges
of ip addresses in CIDR notation. The Access_NoOverRide gives the option
to ignore the IP based authentication for the location in which it is
defined.

=head1 APACHE

  <Location / >

    AuthType Basic
    AuthName "IP Based Auth"

	PerlSetVar Access_AnonUser   "guest"	
	PerlSetVar Access_Ranges     "127.0.0.1/24"	
	PerlSetVar Access_Ips        "127.0.0.1"	
	PerlSetVar Access_NoOverRide "1"	

    PerlAccessHandler KrKit::Control::Access

    require valid-user
 </Location>

=head1 SEE ALSO

KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
