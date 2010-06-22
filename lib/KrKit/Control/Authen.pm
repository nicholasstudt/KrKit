package KrKit::Control::Authen;

use strict;

use Apache2::Const -compile => qw(:common);
use Apache2::Access;
use Apache2::Connection;
use Apache2::Log;
use Apache2::RequestRec;

use KrKit::AppBase;
use KrKit::DB;
use KrKit::SQL;

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	my ( $ret, $sent_pw ) = $r->get_basic_auth_pw;

	return( Apache2::Const::DECLINED ) if ( $ret != Apache2::Const::OK );

	my $user = $r->user;

	unless ( defined $user && $user ) {
		$r->note_basic_auth_failure;
		$r->log_error( 	'[client ', $r->connection->remote_ip, 
						"] user $user not found: ", $r->uri );
		return( Apache2::Const::AUTH_REQUIRED );
	}

	my $dbh = db_connect( appbase_get_dbparam( $r, 1 ) ); 
	
	my $sth = db_query( $dbh, 'Get users password.',
						'SELECT password FROM auth_users WHERE active = \'t\'',
						'AND user_name = ', sql_str( $user ) ); 
	
	my ( $crypt ) = db_next( $sth );
	
	db_finish( $sth );

	db_disconnect( $dbh );

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
						"] user $user: authentication failure for \"", $r->uri,
						'": password mismatch' ); 

		return( Apache2::Const::AUTH_REQUIRED );
	}

	return( Apache2::Const::OK );
} # END $self->handler

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Authen - Database based authentication

=head1 SYNOPSIS 
 
  use KrKit::Control::Authen;

=head1 DESCRIPTION

This module allows authentication against a database.

=head1 APACHE

This is a sample of how to set up Authentication only on a location.

It is important to note that if you turn authentication on without any
users, you will have a very hard time adding yourself. 

  <Location /location/to/auth >
    AuthType    Basic
    AuthName    "Authentication Required"

    PerlSetVar 	DatabaseType 	Pg
    PerlSetVar 	DatabaseServer  server.host.com
    PerlSetVar 	DatabaseName    database_name
    PerlSetVar 	DatabaseUser    database_user
    PerlSetVar 	DatabasePw      database_users_password
    PerlSetVar  DatabaseCommit	off

    PerlAuthenHandler 	KrKit::Control::Authen

    require     valid-user
  </Location>

=head1 DATABASE 

This is the table that will be queried for the authentication of the
user. 

  create table "auth_users" (
    "id"            int4 default nextval('auth_users_seq') NOT NULL,
    "active"        bool,
    "user_name"     varchar,
    "password"      varchar,
    "first_name"    varchar,
    "last_name"     varchar,
    "email"         varchar
  );

=head1 SEE ALSO

KrKit::Control::Authz(3), KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

This and all authentication and autorization modules pre-suppose that
the auth_* tables are in the same database as the application tables.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
