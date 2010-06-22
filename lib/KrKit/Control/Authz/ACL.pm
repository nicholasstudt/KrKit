package KrKit::Control::Authz::ACL;

use strict;

use Apache2::Access;
use Apache2::Const -compile => qw(:common);
use Apache2::RequestRec;

use KrKit::AppBase;
use KrKit::DB;
use KrKit::SQL;
use KrKit::Control;

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# do_requires( $requires, $user, $groups )
#-------------------------------------------------
sub do_requires {
	my ( $requires, $user, $groups ) = @_;

	for my $req_ent ( @$requires ) {
		my ( $req, @rest ) = split( /\s+/, $req_ent->{requirement} );

		# This is kinda odd. Do I really need this ?
		if ( lc( $req ) eq 'valid-user' ) {
			return( Apache2::Const::OK );
		}
		elsif( lc( $req ) eq 'user' ) {
			for my $valid_user ( @rest ) {
				return( Apache2::Const::OK ) if ( $user eq $valid_user );
			}
		}
		elsif( lc( $req ) eq 'group' ) {
			for my $valid_group ( @rest ) {
				return( Apache2::Const::OK ) if ( exists $$groups{$valid_group} );
			}
		}
	}
} # END do_requires

#-------------------------------------------------
# lookup_uri( $dbh, $dbns, @p )
#-------------------------------------------------
sub lookup_uri {
	my ( $dbh, $dbns, @p ) = @_;

	# Sane staring point, nothing works ;)
	my ( $uperm, $gperm, $wperm, $oid, $gid ) = ( 0, 0, 0, 0, 0 );

	# Leave now if no @p
	return( $uperm, $gperm, $wperm, $oid, $gid ) if ( scalar( @p ) < 1 );

	# Figure out what the uri is.
	my $uri = join( '/', @p );
	$uri 	= "/$uri" if ( $uri !~ /^\// );

	# Do the lookup.
	my $sth = db_query( $dbh, 'find the uri', 
						'SELECT perms, owner_id, group_id FROM ',
						"${dbns}auth_acl WHERE uri = ",
						sql_str( $uri ) );

	# If we find it set the vals.
	if ( db_rowcount( $sth ) ) {
		( $uperm, $gperm, $wperm, $oid, $gid ) = db_next( $sth );

		db_finish( $sth );
	}
	else {
		# if not take one down and pass it around.
		db_finish( $sth );

		pop( @p );

		( $uperm, $gperm, $wperm, $oid, $gid ) = lookup_uri( $dbh, $dbns, @p );
	}

	# Return what we have.
	return( $uperm, $gperm, $wperm, $oid, $gid );
} # END lookup_uri

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $self, $r ) = @_;

	my $requires = $r->requires; 

	# If we don't have any requirements get out !
	return( Apache2::Const::DECLINED ) if ( ! $requires );

	# Who's the user ?
	my $user = $r->user;

	# get the uri and fill @p.
	my @p 	= split( '/', $r->uri );
	@p 		= 'index.html' if ( scalar( @p ) < 1 );

	# Get the users groups and put them in a hash.
	my ( %groups, %group_ids, $uperm, $gperm, $wperm, $uid, $oid, $gid );

	### Start Eval
	eval {	
		my $dbtype 	= $r->dir_config( 'DatabaseType' );
		my $dbns	= $r->dir_config( 'DatabaseNameSpace' );
		$dbns		= db_getnamespace( $dbtype, $dbns );
		my $dbh 	= db_connect( appbase_get_dbparam( $r, 1 ) ); 

		# Find the usersid for the user.
		( $uid ) = get_pwnam( $dbh, $user );

		# Eval us !
		my $sth = db_query( $dbh, 'get groups for the user', 
							"SELECT ${dbns}auth_groups.name, ",
							"${dbns}auth_groups.id FROM ",
							"${dbns}auth_groups, ${dbns}auth_group_members ",
							"WHERE ${dbns}auth_group_members.user_id = ",
							sql_num( $uid ), "AND ${dbns}auth_groups.id = ",
							"${dbns}auth_group_members.group_id " );

		while ( my ( $gname, $gid ) = db_next( $sth ) ) {
			$groups{$gname}  = 1;
			$group_ids{$gid} = 1;
		}

		# make the check uri database calls here.
		( $uperm, $gperm, $wperm, $oid, $gid ) = lookup_uri( $dbh, $dbns, @p );

		db_finish( $sth );

		db_disconnect( $dbh );
	};

	# This should actually be Forbidden I believe.
	if ( Apache2::Const::OK ne do_requires( $requires, $user, \%groups ) ) {
		return( Apache2::Const::FORBIDDEN );
	}

	# compare against world
	return( Apache2::Const::OK ) if ( ( dec2bin( $wperm ) )[0] );

	# compare against group
	if ( defined $group_ids{$gid} ) {
		return( Apache2::Const::OK ) if ( ( dec2bin( $gperm ) )[0] );
	}

	# compare against user
	if ( $oid == $uid ) {
		return( Apache2::Const::OK ) if ( ( dec2bin( $uperm ) )[0] );
	}

	# fail if all else dosen't work :( -- bye
	$r->note_basic_auth_failure;

	return( Apache2::Const::FORBIDDEN );
} # END $self->handler

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Authz::ACL - Page based access control.

=head1 SYNOPSIS

  use KrKit::Control::Authz::ACL;

=head1 DESCRIPTION

This handler is the authorization portion for page based authorization.
It is controlled by KrKit::Control::ACLs(3) and will authenticat only
users who have been allowed from the administrative interface into a
particular uri. The module returns FORBIDDEN if you do not have access
to a particular uri.

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

    PerlAuthenHandler KrKit::Control::Authen
    PerlAuthzHandler  KrKit::Control::Authz::ACL

    require     valid-user
  </Location>

=head1 DATABASE 

These are the authentication tables that this handler uses.

  create table "auth_acl" (
    "id"         int4 primary key default nextval('auth_acl_seq') NOT NULL,
    "user_perm"  int4,
    "group_perm" int4,
    "world_perm" int4,
    "owner_id"   int4,
    "group_id"   int4,
    "uri"        varchar,
    "title"      varchar
  );

  create table "auth_groups" (
    "id"          int4 primary key default nextval('auth_groups_seq') NOT NULL,
    "name"        varchar,
    "description" text
  );

  create table "auth_group_members" (
    "id"        int4 primary key default nextval('auth_group_members_seq') 
	            NOT NULL,
    "user_id"   int4,
    "group_id"  int4	
  );

=head1 SEE ALSO

KrKit::Control::ACLs(3), KrKit::Control::Authz(3), KrKit::Control(3),
KrKit(3)

=head1 LIMITATIONS

Pages must be defined for this to work, otherwise everything returns 
FORBIDDEN to the user.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut

