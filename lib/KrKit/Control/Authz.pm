package KrKit::Control::Authz;

use strict;
use Apache2::Const -compile => qw(:common);
use Apache2::Access;
use Apache2::Connection;
use Apache2::RequestRec;

use KrKit::AppBase;
use KrKit::DB;
use KrKit::SQL;

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	my $requires = $r->requires;

	return( Apache2::Const::DECLINED ) unless ( $requires );

	my %groups;
	my $user = $r->user;

	my $dbh = db_connect( appbase_get_dbparam( $r, 1 ) ); 

	my $sth = db_query( $dbh, 'Get users password',
						'SELECT id FROM auth_users WHERE user_name = ',
						sql_str( $user ) ); 

	my ( $user_id ) = db_next( $sth );
	
	db_finish( $sth );

	my $ath = db_query( $dbh, 'Get users Groups',
						'SELECT name FROM auth_groups, auth_group_members ',
						'WHERE ',
						'( auth_groups.id = auth_group_members.group_id ) ',
						'AND ( auth_group_members.user_id = ', 
						sql_num( $user_id ), ')' );

	while ( my ( $name ) = db_next( $ath ) ) {
		$groups{$name} = 1;
	}

	db_finish( $ath );

	db_disconnect( $dbh );

	# Check out what we have to auth against.
	for my $entry ( @$requires ) {
		my ( $req, @rest ) = split( /\s+/, $entry->{requirement} );
		$req = lc( $req );

		if ( $req eq 'valid-user' ) {
			return( Apache2::Const::OK );
		}
		elsif ( $req eq 'user' ) {
			for ( @rest ) { 
				return( Apache2::Const::OK ) if ( $user eq $_ );
			}
		}
		elsif ( $req eq 'group' ) {
			for ( @rest ) { 
				return( Apache2::Const::OK ) if ( exists $groups{$_} );
			}
		}
	}

	return( Apache2::Const::AUTH_REQUIRED ); # Wow you really suck, go away.
} # END $self->handler

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Authz - Database based authorization.

=head1 SYNOPSIS

  use KrKit::Control::Authz;

=head1 DESCRIPTION

This is a simple database driven autorization system. This module also
details the other Authz modules in the library.

=head1 APACHE

This is a sample of how to set up Authorization only on a location.

  <Location /location/to/auth >
    AuthType    Basic
    AuthName    "Manual"

    PerlSetVar 	DatabaseType 	Pg
    PerlSetVar 	DatabaseServer  server.host.com
    PerlSetVar 	DatabaseName    database_name
    PerlSetVar 	DatabaseUser    database_user
    PerlSetVar 	DatabasePw      database_users_password
    PerlSetVar  DatabaseCommit	off

    PerlAuthzHandler  KrKit::Control::Authz

    require     group "group_to_require"
  </Location>

=head1 DATABASE 

These are the tables that will be queried for the authorization of the
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

  create table "auth_groups" (
    "id"            int4 default nextval('auth_groups_seq') NOT NULL,
    "name"          varchar,
    "description"   text
  );

  create table "auth_group_members" (
    "id"        int4 default nextval('auth_group_members_seq') NOT NULL,
    "user_id"   int4,
    "group_id"  int4	
  );

=head1 MODULES

=over 4

=item KrKit::Control::Authz::ACL

This handler is the authorization portion for page based authorization.
It is controlled by KrKit::Control::ACLs(3) and will authenticat only
users who have been allowed from the administrative interface into a
particular uri. The module returns FORBIDDEN if you do not have access
to a particular uri.

=back

=head1 SEE ALSO

KrKit::Control::Authen(3), KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

None ?

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
