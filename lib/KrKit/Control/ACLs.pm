package KrKit::Control::ACLs;

use strict;

use KrKit::Control;
use KrKit::DB;
use KrKit::Handler;
use KrKit::HTML qw(:all);
use KrKit::SQL;
use KrKit::Validate;

############################################################
# Variables                                                #
############################################################
our @ISA = ( 'KrKit::Handler' ); # Inherit the handler.
	
############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $site->do_add( $r )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Add';

	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = page_checkvals( $in ) ) ) {

		for my $bit ( qw( ur uw ux gr gw ge wr ww wx ) ) {
			$in->{$bit} = ( defined $in->{$bit} ) ? 1 : 0;
		}

		my $user 	= ( $in->{ur} * 4 ) + ( $in->{uw} * 2 ) + ( $in->{ux} * 1 );
		my $group 	= ( $in->{gr} * 4 ) + ( $in->{gw} * 2 ) + ( $in->{gx} * 1 );
		my $world 	= ( $in->{wr} * 4 ) + ( $in->{ww} * 2 ) + ( $in->{wx} * 1 );
		my $perms 	= "$user$group$world";
	
		db_run( $$site{dbh}, 'insert new page', 
				sql_insert( "$$site{dbns}auth_acl", 
							'owner_id' 	=> sql_num( $in->{user} ),
							'group_id' 	=> sql_num( $in->{group} ),
							'perms'		=> sql_str( $perms ), 
							'uri' 		=> sql_str( $in->{uri} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, page_form( $site, $in ) );
		}
		else {
			return( page_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete Page'; 
	
	return( 'Invalid id' ) 							if ( ! is_integer( $id ) );
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );
	
	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'Delete from pages', 
				"DELETE FROM $$site{dbns}auth_acl WHERE id = ", 
				sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );	
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get page name',
							"SELECT uri, perms FROM $$site{dbns}auth_acl ",
							'WHERE id = ', sql_num( $id ) );  

		my ( $uri, $perms ) = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 

				ht_div( { 'class' => 'box' } ),	
				ht_table(),
				ht_tr(),
				ht_td( 	{ 'class' => 'dta' }, 
						'Do you really want to delete the ACL',
						" '$uri' ($perms)?" ),
				ht_utr(),

				ht_tr(),
				ht_td( 	{ 'class' => 'rshd' },
						ht_submit( 'submit', 'Continue with Delete' ),
						ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}
} # END $site->do_delete

#-------------------------------------------------
# $site->do_edit( $r, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Update Page';

	return( 'Invalid id.' ) 						if ( ! is_number( $id ) );
	return( $site->_relocate( $r, $$site{rootp} ) ) if ( $in->{cancel} );

	if ( ! ( my @errors = page_checkvals( $in ) ) ) {

		for my $bit ( qw( ur uw ux gr gw gx wr ww wx ) ) {
			$in->{$bit} = ( defined $in->{$bit} ) ? 1 : 0;
		}

		my $user 	= ( $in->{ur} * 4 ) + ( $in->{uw} * 2 ) + ( $in->{ux} * 1 );
		my $group 	= ( $in->{gr} * 4 ) + ( $in->{gw} * 2 ) + ( $in->{gx} * 1 );
		my $world 	= ( $in->{wr} * 4 ) + ( $in->{ww} * 2 ) + ( $in->{wx} * 1 );
		my $perms 	= "$user$group$world";
	
		db_run( $$site{dbh}, 'insert new page', 
				sql_update( "$$site{dbns}auth_acl", 
									'WHERE id = '. sql_num( $id ),
							'perms' 	=> sql_num( $perms ),
							'owner_id' 	=> sql_num( $in->{user} ),
							'group_id' 	=> sql_num( $in->{group} ),
							'uri' 		=> sql_str( $in->{uri} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old value', 
							'SELECT perms, owner_id, group_id, uri FROM',
							"$$site{dbns}auth_acl WHERE id = ",
							sql_num( $id ) );
		
		while( my ( $perms, $oid, $gid, $uri ) = db_next( $sth ) ) {

			my ( $up, $gp, $wp ) = split( //, $perms ); 

			if ( ( ! defined $in->{ur} ) || ( ! defined $in->{uw} ) || 
				 ( ! defined $in->{ux} ) ) {
				 ( $in->{ur}, $in->{uw}, $in->{ux} ) = dec2bin( $up );
			}

			if ( ( ! defined $in->{gr} ) || ( ! defined $in->{gw} ) || 
				 ( ! defined $in->{gx} ) ) {
				 ( $in->{gr}, $in->{gw}, $in->{gx} ) = dec2bin( $gp );
			}

			if ( ( ! defined $in->{wr} ) || ( ! defined $in->{ww} ) || 
				 ( ! defined $in->{wx} ) ) {
				 ( $in->{wr}, $in->{ww}, $in->{wx} ) = dec2bin( $wp );
			}

			$in->{user} 	= $oid 		if ( ! defined $in->{user} );	
			$in->{group} 	= $gid 		if ( ! defined $in->{group} );	
			$in->{uri} 		= $uri 		if ( ! defined $in->{uri} );	
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, page_form( $site, $in ) );
		}
		else {
			return( page_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r, $order )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $order ) = @_;

	$$site{page_title} .= 'List ACLs';

	# Set any order from the clicks.
	my $orderby = 'uri';

	if ( is_text( $order ) ) {
		$orderby = 'perms'				if ( $order =~ /perm/ );
		$orderby = 'user_name' 			if ( $order =~ /user/ );
		$orderby = 'auth_groups.name'	if ( $order =~ /group/ );
		$orderby = 'uri' 				if ( $order =~ /uri/ );
	}

	my @lines = (	ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' },
							ht_a( "$$site{rootp}/main/perm", 'Perms' ) ), 
					ht_td( 	{ 'class' => 'shd' },
							ht_a( "$$site{rootp}/main/user", 'User' ) ),
					ht_td( 	{ 'class' => 'shd' }, 
							ht_a( "$$site{rootp}/main/group", 'Group' ) ),
					ht_td( 	{ 'class' => 'shd' },
							ht_a( "$$site{rootp}/main/uri", 'URI' ) ),
					ht_td( 	{ 'class' => 'rshd' }, 
							'[', ht_a( "$$site{rootp}/add", 'Add Page' ),']'),
					ht_utr() );

	my $dbns = $$site{dbns};
	my $sth = db_query( $$site{dbh}, 'List all users',
						"SELECT ${dbns}auth_acl.id, perms, owner_id, ",
						'first_name, last_name, email, group_id, ',
						"${dbns}auth_groups.name, uri ",
						"FROM ${dbns}auth_acl, ${dbns}auth_groups,",
						"${dbns}auth_users WHERE ",
						"${dbns}auth_acl.owner_id = ${dbns}auth_users.id AND ",
						"${dbns}auth_acl.group_id = ${dbns}auth_groups.id ",
						'ORDER BY', $orderby );

	while( my ( $id, $perms, $oid, $fname, $lname, $email, $gid, $gname,
				$uri ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),	
						ht_td( 	{ 'class' => 'dta' }, $perms ),
						ht_td(  { 'class' => 'dta' }, "$fname $lname" ),	
						ht_td(  { 'class' => 'dta' }, $gname ),
						ht_td( 	{ 'class' => 'dta' }, $uri ),
						ht_td( 	{ 'class' => 'rdta' },
								'[',
								ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
								ht_a( "$$site{rootp}/delete/$id", 'Delete' ), 
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),	
						ht_td( 	{ 'colspan' => '5', 'class' => 'cdta' },
								'No pages found.' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# page_checkvals( $in )
#-------------------------------------------------
sub page_checkvals {
	my $in = shift;

	my @errors;

	if ( ! is_text( $in->{uri} ) ) {
		push( @errors, 'Enter a path.'. ht_br() );
	}
	else {
		if ( $in->{uri} !~ /^\// ) {
			push( @errors, 'Path must start with a "/".'. ht_br() );
		}

		if ( $in->{uri} =~ /\s/ ) {
			push( @errors, 'Path may not contain spaces.'. ht_br() );
		}
	}

	if ( ! is_number( $in->{user} ) ) {
		push( @errors, 'Select an user.'. ht_br() );
	}

	if ( ! is_number( $in->{group} ) ) {
		push( @errors, 'Select a group.'. ht_br() );
	}

	return( @errors );
} # END page_checkvals

#-------------------------------------------------
# page_form( $site, $in )
#-------------------------------------------------
sub page_form {
	my ( $site, $in ) = @_;

	my @users 	= ( '', '- Select -' );
	my @groups 	= ( '', '- Select -' );

	# Make array of users.
	my $sth = db_query( $$site{dbh}, 'get user list', 
						'SELECT id, user_name, first_name, last_name ', 
						"FROM $$site{dbns}auth_users ORDER BY ",
						'last_name, first_name' );
	
	while( my ( $id, $uname, $fname, $lname ) = db_next( $sth ) ) {
		push( @users, $id, "$fname $lname ($uname)" ); 
	}

	db_finish( $sth );

	# Make array of groups.
	my $ath = db_query( $$site{dbh}, 'get group list', 
						"SELECT id, name FROM $$site{dbns}auth_groups ",
						'ORDER BY name' );

	while ( my ( $id, $name ) = db_next( $ath ) ) {
		push( @groups, $id, $name );
	}

	db_finish( $ath );

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Page (path)' ),
			ht_td( 	{ 'class' => 'dta' },	
					ht_input( 'uri', 'text', $in, 'size="30"' ),
					ht_help( $$site{help}, 'item', 'm:c:p:page' ) ),
			ht_utr(),
	
			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'User' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_select( 'user', 1, $in, '', '', @users ),
					ht_help( $$site{help}, 'item', 'm:c:p:user' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Group' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_select( 'group', 1, $in, '', '', @groups ),
					ht_help( $$site{help}, 'item', 'm:c:p:group' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Permissions',
					ht_help( $$site{help}, 'item', 'm:c:p:perms' ) ),
			ht_td( 	{ 'class' => 'dta' },	
					ht_table(),
					ht_tr(),
					ht_td( { 'class' => 'shd' }, 'User' ),
					ht_td( { 'class' => 'shd' }, 'Group' ),
					ht_td( { 'class' => 'shd' }, 'World' ),
					ht_utr(),

					ht_tr(),
					ht_td( { 'class' => 'dta' }, 	
							ht_checkbox( 'ur', 1, $in ), 'Read', ht_br(),
							ht_checkbox( 'uw', 1, $in ), 'Write', ht_br(),
							ht_checkbox( 'ux', 1, $in ), 'Execute' ),
					ht_td( { 'class' => 'dta' }, 	
							ht_checkbox( 'gr', 1, $in ), 'Read', ht_br(),
							ht_checkbox( 'gw', 1, $in ), 'Write', ht_br(),
							ht_checkbox( 'gx', 1, $in ), 'Execute' ),
					ht_td( { 'class' => 'dta' }, 	
							ht_checkbox( 'wr', 1, $in ), 'Read', ht_br(),
							ht_checkbox( 'ww', 1, $in ), 'Write', ht_br(),
							ht_checkbox( 'wx', 1, $in ), 'Execute' ),
					ht_utr(),

					ht_utable()	),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save'  ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END page_form

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::ACLs - ACL based control adminstration.

=head1 SYNOPSIS

  use KrKit::Control::ACLs;

=head1 DESCRIPTION

This module is the frontend for the KrKit::Control::Authz::PageBased
authentication handler. One would specify pages as well as the
permissions with this frontend module.

=head1 APACHE

This is a sample of how the configuration of the handler might appear
in a random httpd.conf. It list all of the variables that the module
will use from the enviroment. These variables, being fairly common, are
document in KrKit::Framing(3), and KrKit::Appbase(3)

  <Location /admin/pages >
	SetHandler 	perl-script

    PerlSetVar  SiteTitle       "Page Access: "
    PerlSetVar  Frame           template;tick.tp

    PerlSetVar  DatabaseType    Pg
    PerlSetVar  DatabaseServer  tick.sunflower.com
    PerlSetVar  DatabaseName    alchemy	
    PerlSetVar  DatabaseUser    dwarf	
    PerlSetVar  DatabasePw      w3bdb
    PerlSetVar  DatabaseCommit  off

 	PerlHandler KrKit::Control::ACLs
  </Location>

=head1 DATABASE 

This is the auth_pages table that is used by this module. It also uses
the auth_users and auth_groups tables for reference. 

  create table "auth_acl" (
    "id"        int4 primary key default nextval('auth_acl_seq') NOT NULL,
    "perms"     varchar,
    "owner_id"  int4,
    "group_id"  int4,
    "uri"       varchar
  );

=head1 SEE ALSO

KrKit::Control(3), KrKit::Control::Users(3), KrKit::Control::Groups(3),
KrKit::Control::Authz::ACL(3)

=head1 LIMITATIONS

The uri field must be a relative uri and not contain the protocol.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
