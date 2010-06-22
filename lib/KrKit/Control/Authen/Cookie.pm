package KrKit::Control::Authen::Cookie;

use strict;

use Apache2::Const -compile => qw(:common);
use Apache2::RequestUtil;

use KrKit::AppBase;
use KrKit::Control;
use KrKit::DB;
use KrKit::SQL;
use KrKit::Validate;

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	return( Apache2::Const::DECLINED ) unless $r->is_initial_req;

	warn( "Auth::Cookie" );

	my $cname 		= $r->dir_config( 'Auth_Cookie_Name' ) || 'authcookie';
	my $cpath 		= $r->dir_config( 'Auth_Cookie_Path' ) || '/';
	my $duration 	= $r->dir_config( 'Auth_Cookie_Duration' ) || 0;
	my $expire 		= ( $duration > 0 ) ? $duration : undef ;
	my $cookies 	= appbase_cookie_retrieve( $r );

	# XXX The following construct doesn't really keep a logged out user
	# from getting access... ( But I need to test to verify )
	if ( is_text( $$cookies{$cname} ) ) {
		$$cookies{$cname} = '' if ( $$cookies{$cname} =~ /^loggedout$/ );
	}

	if ( ! is_text( $$cookies{$cname} )  ) {
		warn( "Auth::Cookie - No cookie" );

		# Get the password and username from the client.
		my ( $ret, $sent_pw  ) = $r->get_basic_auth_pw;
	
		return( Apache2::Const::DECLINED ) if ( $ret != Apache2::Const::OK );
	
		my $user = $r->user;

		unless ( defined $user && $user ) {
			$r->note_basic_auth_failure;
			$r->log_error( 	'[client ', $r->connection->remote_ip, 
							"] user $user not found: ", $r->uri );
			return( Apache2::Const::AUTH_REQUIRED );
		}

		my $dbh = db_connect( appbase_get_dbparam( $r, 1 ) ); 
		
		my ( $id, $active, $crypt ) = ( get_pwnam( $dbh, $user ) )[0..2];
	
		db_disconnect( $dbh );

		# User is disabled.
		if ( ! $active ) {
			$r->note_basic_auth_failure;
			$r->log_error( 	'[client ', $r->connection->remote_ip, 
							"] user $user: authentication failure for \"", 
							$r->uri, '": user disabled' ); 

			return( Apache2::Const::AUTH_REQUIRED );
		}

		# Do error here.
		unless ( defined $crypt && $crypt ) {
			$r->note_basic_auth_failure;
			$r->log_error( 	'[client ', $r->connection->remote_ip, 
							"] user $user not found: ", $r->uri );
			return( Apache2::Const::AUTH_REQUIRED );
		}

		# do a error here as well.
		unless ( crypt( $sent_pw, $crypt ) eq $crypt ) {
			$r->note_basic_auth_failure;
			$r->log_error( 	'[client ', $r->connection->remote_ip, 
							"] user $user: authentication failure for \"", 
							$r->uri, '": password mismatch' ); 

			return( Apache2::Const::AUTH_REQUIRED );
		}

		# The user/crypt string should have something done to it.
		appbase_cookie_set( $r, $cname, "$user|~|$crypt", $expire, $cpath );

		return( Apache2::Const::OK );
	}
		
	warn( "Auth::Cookie - Have Cookie" );

	# Confirm the cookie information.
	my ( $user, $pass ) = split( /\|~\|/, $$cookies{$cname} );

	if ( ! is_text( $pass ) ) {
		$r->note_basic_auth_failure; 
    	$r->log_error(  '[client ', $r->connection->remote_ip,
						'] user not found: ', $r->uri );

		return( Apache2::Const::AUTH_REQUIRED );
	}

	my $dbh = db_connect( appbase_get_dbparam( $r, 1 ) );

	my ( $id, $active, $password ) = ( get_pwnam( $dbh, $user ) )[0..2];

	db_disconnect( $dbh );

	# Confirm the cookie information.
	if ( ( ! is_integer( $id ) ) || ( ! $active ) || ( $pass ne $password ) ) {
		$r->note_basic_auth_failure; 
    	$r->log_error(  '[client ', $r->connection->remote_ip,
						'] user not found: ', $r->uri );

		return( Apache2::Const::AUTH_REQUIRED );
	}

	# Reset the cookie !
	appbase_cookie_set( $r, $cname, "$user|~|$password", $expire, $cpath );

	# Make sure we ok them the rest of the way through.
	# FIXME: This line may cause problems.
	#$r->set_handlers( PerlAuthzHandler  => [\&Apache2::Const::OK] );
	$r->user( $user );

	return( Apache2::Const::OK ); 
} # END handler 

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Authen::Cookie - Cookie based authentication.

=head1 DESCRIPTION

=head1 APACHE

  <Location / >
    AuthType Basic
    AuthName "KrKit_Auth_Cookie"

    PerlAuthenHandler KrKit::Control::Authen::Cookie
    
    require valid-user
</Location>

=head1 DATABASE

This module will read from the auth_users table.

=head1 SEE ALSO

KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

The cookie uses the string "|~|" as the seperator between the username
and the password.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
