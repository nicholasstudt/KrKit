package KrKit::Control::Groups;

use strict; # It worked for your mother when you were a kid.

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
# $self->do_add( $r, $site )
#-------------------------------------------------
sub do_add {
	my ( $site, $r ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Add Group';

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = group_checkvals( $in ) ) ) {

		# Clean up the variables some.
		( my $desc = $in->{desc} ) =~ s/\r//g;
		$desc 		=~ s/\n/<BR>/g;
		$in->{name} =~ s/\s+/\_/g;

		db_run( $$site{dbh}, 'Insert a new group',
				sql_insert( 'auth_groups',
				 			'name'			=> sql_str( $in->{name} ),
				 			'description'	=> sql_str( $desc ) ) );

		# Get the last id and then add all the users.
		my $groupid = db_lastseq( $$site{dbh}, 'auth_groups_seq' );

		for my $userid ( split( ':', $in->{all_users} ) ) {
			next if ( ! defined $in->{"user_$userid"} );

			db_run( $$site{dbh}, 'Insert the users',
					sql_insert( 'auth_group_members',
					 			'user_id'	=>	sql_num( $userid ),
								'group_id'	=>	sql_num( $groupid ) ) );
		}

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, group_form( $site, $in ) );
		}
		else {
			return( group_form( $site, $in ) );
		}
	}
} # END do_add 

#-------------------------------------------------
# $self->do_delete( $r, $site, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete Group'; 

	return( 'Invalid id' ) if ( ! is_number( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'Delete from user groups', 
				'DELETE FROM auth_group_members WHERE group_id = ',
				sql_num( $id ) );

		db_run( $$site{dbh}, 'Delete from groups', 
				'DELETE FROM auth_groups WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );	
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get group name',
							'SELECT name FROM auth_groups WHERE id = ', 
							sql_num( $id ) );  

		my $name = db_next( $sth );

		db_finish( $sth );

		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table(),
				ht_tr(),
				ht_td( 	{ 'class' => 'dta' }, 
						'Do you really want to delete the group', "'$name'?" ),
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
} # END do_delete 

#-------------------------------------------------
# $self->do_edit( $r, $site, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Update Group';

	return( 'Invalid group id.' ) if ( ! is_number( $id ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = group_checkvals( $in ) ) ) {

		my %users;
		( my $desc = $in->{desc} ) =~ s/\r//g;
		$desc 			=~ s/\n/<BR>/g;
		$in->{name} 	=~ s/\s+/\_/g;

		db_run( $$site{dbh}, 'Insert a new group',
				sql_update( 'auth_groups', 'WHERE id = '. sql_num( $id ),
				 			'name'			=> sql_str( $in->{name} ),
				 			'description'	=> sql_str( $desc ) ) );

		for my $user ( split( ':', $in->{current_users} ) ) {
			$users{$user} = 1;
		}

		for my $entry ( split( ':', $in->{all_users} ) ) {

			if ( defined $in->{"user_$entry"} ) {
				# if they were already defined next
				next if ( defined $users{$entry} );

				# if not add them.
				db_run( $$site{dbh}, 'Insert the users',
						sql_insert( 'auth_group_members',
						 			'user_id'	=>	sql_num( $entry ),
									'group_id'	=>	sql_num( $id ) ) );
			}
			else {
				# if the were not already defined next
				next if ( ! defined $users{$entry} );

				# if they were delete them.
				db_run( $$site{dbh}, 'delete a user', 
						'DELETE FROM auth_group_members WHERE user_id = ',
						sql_num( $entry ), 'AND group_id = ', sql_num( $id ) );
			}
		}

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my @current_users;

		my $sth = db_query( $$site{dbh}, 'get old values',
							'SELECT name, description FROM auth_groups ',
							'WHERE id = ', sql_num( $id ) );

		while ( my ( $name, $desc ) = db_next( $sth ) ) {
			$in->{name} = $name if ( ! defined $in->{name} );

 			if ( ! defined $in->{desc} ) {
				( $in->{desc} = $desc ) =~ s/<BR>/\n/g;
			}
		}

		db_finish( $sth );

		my $ath = db_query( $$site{dbh}, 'Get existing users',
							'SELECT user_id FROM auth_group_members WHERE ',
							'group_id = ', sql_num( $id ) );

		while ( my ( $user ) = db_next( $ath ) ) {
			push( @current_users, $user );
			$in->{"user_$user"} = 1 if ( ! defined $in->{"user_$user"} );
		}

		$in->{current_users} = join( ':', @current_users );

		db_finish( $ath );

		if ( $r->method eq 'POST' ) {
			return( @errors, group_form( $site, $in ) );
		}
		else {
			return( group_form( $site, $in ) );
		}
	}
} # END do_edit 

#-------------------------------------------------
# $self->do_main( $r, $site )
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	$$site{page_title} .= 'Groups Listing';

	my @lines = ( 	ht_div( { 'class' => 'box' } ),	
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, ht_b( 'Group Name' ) ),
					ht_td( 	{ 'class' => 'rshd' },
							'[', ht_a( "$$site{rootp}/add", 'Add' ), ']'),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'Select all groups', 
						'SELECT id, name FROM auth_groups ORDER BY name' );
	
	while ( my ( $id, $name ) = db_next( $sth ) ) {

		push( @lines,	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, $name ),
						ht_td( 	{ 'class' => 'rdta' },
								'[',
								ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
								ht_a( "$$site{rootp}/delete/$id", 'Delete' ),
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines,	ht_tr(),
						ht_td( 	{ 'colspan' => '2', 'class' => 'cdta' },
								'No groups found.' ),
						ht_utr() );
	}
	
	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END do_main 

#-------------------------------------------------
# group_checkvals( $in )
#-------------------------------------------------
sub group_checkvals ($) {
	my $in = shift;

	my @errors;

	if ( ! is_text( $in->{name} ) ) { 
		push( @errors, 'Groups must have a name.'. ht_br() );
	}

	if ( ! is_text( $in->{desc} ) ) { 
		push( @errors, 'Groups must have a description.'. ht_br() );
	}

	# We don't sanity check the people in the groups because we want to
	# let people have empty groups, ie they have data dependant on the
	# group but they don't want anyone to be able to see that groups
	# stuff or something like that.

	return( @errors );
} # END group_checkvals 

#-------------------------------------------------
# group_form( $site, $in )
#-------------------------------------------------
sub group_form ($$) {
	my ( $site, $in ) = @_;

	my ( $count, @left, @right, @all ) = ( 0 );

	my @lines = ( 	ht_form_js( $$site{uri} ),
					ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Group Name' ),
					ht_td( 	{ 'class' => 'dta' }, 	
							ht_input( 'name', 'text', $in, 'size="40"' ),
							ht_help( $$site{help}, 'item', 'm:c:g:gname' )),
					ht_utr(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Group Description' ),
					ht_td( 	{ 'class' => 'dta' }, 
							ht_input( 	'desc', 'textarea', $in, 
										'cols="40" rows="5"' ),
							ht_help( $$site{help}, 'item', 'm:c:g:gdesc' )),
					ht_utr(),

					ht_tr(),
					ht_td( 	{ 'class' => 'chdr', 'colspan' => '2' },
							'Users in Group',
							ht_help( $$site{help}, 'item', 'm:c:g:gusers' ) ),
					ht_utr() );

	# Yes I realize this will not show disabled users, they shouldn't
	# be able to be added to a group because most likely they are dead
	# in the system.
	my $sth = db_query(	$$site{dbh}, 'Get all active users',
						'SELECT id, first_name, last_name, user_name FROM ',
						'auth_users WHERE active =\'t\' ORDER BY last_name, ',
						'first_name' );

	my $total = db_rowcount( $sth );
	
	while ( my ( $id, $fname, $lname, $uname ) = db_next( $sth ) ) {

		$in->{"user_$id"} = 1 if ( defined $in->{"user_$id"} );

		push( @all, $id );

		if ( $count < ( $total / 2 ) ) {
			push( @left, 	ht_checkbox( "user_$id", 1, $in ),
							"$fname $lname ($uname)". ht_br() );
		}
		else {
			push( @right, 	ht_checkbox( "user_$id", 1, $in ),
							"$fname $lname ($uname)". ht_br() );
		}
		$count++;
	}

	db_finish( $sth );

	$in->{all_users} 		= join( ':', @all );
	$in->{current_users} 	= '' if ( ! defined $in->{current_users} );

	return(	@lines, 	
			ht_tr(),
			ht_td( { 'colspan' => '2', 'class' => 'dta' }, 
					ht_table(),
					ht_tr(),
					ht_td( { 'class' => 'dta' }, @left ),
					ht_td( { 'class' => 'dta' }, @right ),
					ht_utr(),
					ht_utable() ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_input( 'all_users', 'hidden', $in ),
					ht_input( 'current_users', 'hidden', $in ),
					ht_submit( 'submit', 'Save' ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),
			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END group_form 

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Groups - Group management for the KrKit library

=head1 SYNOPSIS

  use KrKit::Control::Groups;

=head1 DESCRIPTION

This module handles all of the group manipulation for the authorization
and authentication handlers. It's pretty mundane by itself.

=head1 APACHE

This is a sample of how the configuration of the handler might appear
in a random httpd.conf. It list all of the variables that the module
will use from the enviroment. These variables, being fairly common, are
document in KrKit::Framing(3), and KrKit::Appbase(3)

  <Location /Admin/Groups >
    SetHandler  perl-script

    PerlSetVar  SiteTitle       "Group Management: "
    PerlSetVar  Frame           template;tick.tp

    PerlSetVar  DatabaseType    Pg
    PerlSetVar  DatabaseServer  tick.sunflower.com
    PerlSetVar  DatabaseName    alchemy	
    PerlSetVar  DatabaseUser    dwarf	
    PerlSetVar  DatabasePw      w3bdb
    PerlSetVar  DatabaseCommit  off

    PerlHandler KrKit::Control::Groups
  </Location>

=head1 DATABASE 

These are the group authentication/authorization tables used by this
module. They are also used by the authen and authz handlers this package
contains.

  create table "auth_groups" (
    "id"            int4 default nextval('auth_groups_seq'::text) NOT NULL,
    "name"          varchar,
    "description"   text
  );

  create table "auth_group_members" (
    "id"        int4 default nextval('auth_group_members_seq'::text) NOT NULL,
    "user_id"   int4,
    "group_id"  int4	
  );

=head1 SEE ALSO

KrKit::Control::Users(3), KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

The group name should be safe for use in the apache configuration files
but I am not going to force this down peoples throat as any string can
be made safe if escaped correctly.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
