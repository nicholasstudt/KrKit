package KrKit::Control::Users;

use strict; # It worked for your mother when you were a kid.

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
	$$site{page_title} 	.= 'Add User';

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = user_checkvals( $site, $in, 'add' ) ) ) {

		db_run( $$site{dbh}, 'Insert a new user',
				sql_insert( 'auth_users', 
				 			'active'	=> sql_bool( 't' ),
							'user_name'	=> sql_str( lc( $in->{uname} ) ),
							'password'	=> sql_str( encrypt( $in->{pass} ) ),
							'first_name'=> sql_str( $in->{fname} ),
							'last_name'	=> sql_str( $in->{lname} ),
							'email'		=> sql_str( $in->{email} ) ) );

		my $userid = db_lastseq( $$site{dbh}, 'auth_users_seq' );

		for my $grp ( ( ref( $in->{groups} ) eq 'ARRAY') ? 
							@{$in->{groups}} : $in->{groups} ) {
			
			db_run( $$site{dbh}, 'Update a user',
					sql_insert( 'auth_group_members',
								'user_id' 	=> sql_num( $userid ),
								'group_id' 	=> sql_num( $grp ) ) );
		}

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, user_form( $site, $in, 'add' ) );
		}
		else {
			return( user_form( $site, $in, 'add' ) );
		}
	}
} # END $site->do_add  

#-------------------------------------------------
# $site->do_delete( $r, $userid, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $userid, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete User';

	return( 'Invalid user id.' ) if ( ! is_number( $userid ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'Delete a user.', 
				'DELETE FROM auth_users WHERE id = ', sql_num( $userid ) );

		db_run( $$site{dbh}, 'Delete a user.', 
				'DELETE FROM auth_group_members WHERE user_id = ',
				sql_num( $userid ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table(),
				ht_tr(),
				ht_td( { 'class' => 'dta' }, 
						q!Other applications may depend on this users id!,
						q!being in the table, should we really delete it?!,
						ht_br(), q!Why not !,
						ht_a( "$$site{rootp}/disable/$userid", 'disable' ),
						q!the user?! ),
				ht_utr(),
				ht_tr(),
				ht_td( { 'class' => 'rshd' }, 
						ht_submit( 'submit', 'Continue with Delete' ),
						ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}
} # END do_delete  

#-------------------------------------------------
# $site->do_disable( $r, $userid )
#-------------------------------------------------
sub do_disable {
	my ( $site, $r, $userid ) = @_;
	
	$$site{page_title} .= 'Disable User';

	return( 'Invalid user id.' ) if ( ! is_number( $userid ) );

	my $sth = db_query( $$site{dbh}, 'Get current status',
						'SELECT active FROM auth_users WHERE id = ',
						sql_num( $userid ) );

	my ( $abled ) = db_next( $sth );

	db_finish( $sth );

	db_run( $$site{dbh}, 'Update Abled status',
			sql_update( 'auth_users', 'WHERE id = '. sql_num( $userid ),
			 			'active' => sql_bool( ( $abled ) ? 'f' : 't' ) ) );

	db_commit( $$site{dbh} );

	return( $site->_relocate( $r, $$site{rootp} ) );
} # END do_disable  

#-------------------------------------------------
# $site->do_edit( $r, $userid )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $userid ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Update User';
	
	return( 'Invalid user id' )	if ( ! is_number( $userid ) );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, $$site{rootp} ) );
	}

	if ( ! ( my @errors = user_checkvals( $site, $in, 'edit' ) ) ) {

		db_run( $$site{dbh}, 'Update a user',
				sql_update( 'auth_users', 'WHERE id = '. sql_num( $userid ), 
							'user_name'	=>	sql_str( lc( $in->{uname} ) ),
							'first_name'=>	sql_str( $in->{fname} ),
							'last_name'	=>	sql_str( $in->{lname} ),
							'email'		=>	sql_str( $in->{email} ) ) );

		if ( ( defined $in->{pass} ) && ( length( $in->{pass} ) > 1 ) ) {
			my $pass = encrypt( $in->{pass} );

			db_run( $$site{dbh}, 'Update a user',
					sql_update( 'auth_users', 'WHERE id = '. sql_num( $userid ),
								'password' => sql_str( $pass ) ) );
		}

 		my $grps = get_usrgrp( $$site{dbh}, $userid );

		# Fear my if statements.
		for my $grp ( ( ref( $in->{groups} ) eq 'ARRAY') ? 
							@{$in->{groups}} : $in->{groups} ) {
			
			if ( $$grps{$grp} ) {
				delete( $$grps{$grp} );
				next;
			}
	
			# Add.
			db_run( $$site{dbh}, 'Update a user',
					sql_insert( 'auth_group_members',
								'user_id' 	=> sql_num( $userid ),
								'group_id' 	=> sql_num( $grp ) ) );
		}

		# Remove whats still in $grps
		for my $grp ( keys %{$grps} ) { 
			db_run( $$site{dbh}, 'remove unused',
					'DELETE FROM auth_group_members WHERE user_id = ',
					sql_num( $userid ), 'AND group_id = ', sql_num( $grp ) );
		}

		db_commit( $$site{dbh} );
		
		return( $site->_relocate( $r, $$site{rootp} ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'Get old values',
							'SELECT user_name, first_name, last_name, ',
							'email FROM auth_users WHERE id = ',
							sql_num( $userid ) );

		while ( my ( $uname, $fname, $lname, $email ) = db_next( $sth ) ) {
			$in->{ouname} 	= $uname;
			$in->{uname} 	= $uname 	if ( ! defined $in->{uname} );
			$in->{fname} 	= $fname 	if ( ! defined $in->{fname} );
			$in->{lname} 	= $lname 	if ( ! defined $in->{lname} );
			$in->{email} 	= $email 	if ( ! defined $in->{email} );
		}
		
		db_finish( $sth );	

		# Get user groups.
		if ( ! defined $in->{groups} ) {
 			my @grps 		= keys( %{get_usrgrp( $$site{dbh}, $userid )} );
			$in->{groups} 	= \@grps; 
		}

		if ( $r->method eq 'POST' ) {
			return( @errors, user_form( $site, $in, 'edit' ) );
		}
		else {
			return( user_form( $site, $in, 'edit' ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r, $order )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $order ) = @_;

	$$site{page_title} .= 'List Users';

	# pick the order to sort by.
	my $orderby = 'last_name, first_name';

	if ( is_text( $order ) ) {
		$orderby = 'user_name' 	if ( $order =~ /uname/ );
		$orderby = 'active'		if ( $order =~ /stat/ );
	}

	my @lines = (	ht_div( { 'class' => 'box' } ),
					ht_table(),
					ht_tr(),
					ht_td( 	{ 'class' => 'shd' },
							ht_a( "$$site{rootp}/main/name", 'Name' ) ), 
					ht_td( 	{ 'class' => 'shd' }, 
							ht_a( "$$site{rootp}/main/uname", 'Username' ) ), 
					ht_td( 	{ 'class' => 'shd' }, 
							ht_a("$$site{rootp}/main/stat", 'Active Status') ),
					ht_td( 	{  'class' => 'rshd' }, 
							ht_a( 	"$$site{rootp}/add", 'Add User',
								 	'rel="new"' ), ),
					ht_utr() );

	my $sth = db_query( $$site{dbh}, 'List all users',
						'SELECT id, active, user_name, first_name, last_name ',
						'FROM auth_users ORDER BY ', $orderby );

	while( my( $id, $abled, $username, $fname, $lname ) = db_next( $sth ) ) {

		$abled = ( $abled ) ? 'Enabled' : 'Disabled';
		$fname = '' if ( ! defined $fname );

		push( @lines, 	ht_tr(),	
						ht_td( 	{ 'class' => 'dta' }, 
								ht_a( 	"$$site{rootp}/user/$id",
										"$fname $lname" ) ),	
						ht_td( 	{ 'class' => 'dta' }, $username ),
						ht_td( 	{ 'class' => 'dta' },
								ht_a( "$$site{rootp}/disable/$id", $abled ) ),
						ht_td( 	{ 'class' => 'rdta' },
								'[',
								ht_a( 	"$$site{rootp}/edit/$id", 'Edit', 
										'rel="edit"' ), '|',
								ht_a( 	"$$site{rootp}/delete/$id", 'Delete',
										'rel="delete"' ), 
								']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),	
						ht_td( 	{ 'colspan' => '4', 'class' => 'cdta' },
								'No users found.' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main  

#-------------------------------------------------
# $site->do_user( $r, $id, $action, $group )
#-------------------------------------------------
sub do_user {
	my ( $site, $r, $id, $action, $group ) = @_;
	
	$$site{page_title} .= 'User Detail';

	return( 'Invalid id.' ) if ( ! is_number( $id ) );

	# Add or remove the group that is specified.
	if ( defined $action ) {
		return( 'Invalid group id.' ) if ( ! is_number( $group ) );

		if ( $action =~ /add/ ) {  # Add them 
			db_run( $$site{dbh}, 'add user to group',
					sql_insert( 'auth_group_members', 
								'group_id' 	=> sql_num( $group ),
								'user_id' 	=> sql_num( $id ) ) );
		}
		else { # Remove them.
			db_run( $$site{dbh}, 'remove user from group',
					'DELETE FROM auth_group_members WHERE user_id = ',
					sql_num( $id ), 'AND group_id =', sql_num( $group ) );
		}

		db_commit( $$site{dbh} );
	}

	# Show the user and all groups they are in / are not in.
	my $sth = db_query( $$site{dbh}, 'get details for the user.',
						'SELECT active, user_name, first_name, last_name, ',
						'email FROM auth_users WHERE id = ', sql_num( $id ) );

	my ( $active, $uname, $fname, $lname, $email ) = db_next( $sth );

	db_finish( $sth );
	
	my @lines = ( 	ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( { 'class' => 'rhdr', 'colspan' => '2' },
							'[', ht_a( $$site{rootp}, 'Main' ), '|',
							ht_a( "$$site{rootp}/edit/$id", 'Edit' ), '|',
							ht_a( "$$site{rootp}/delete/$id", 'Delete' ), ']' ),
					ht_utr(),

					ht_tr(),
					ht_td( { 'class' => 'shd' }, 'Name' ),
					ht_td( { 'class' => 'dta' }, $fname, $lname ),
					ht_utr(),

					ht_tr(),
					ht_td( { 'class' => 'shd' }, 'E-mail' ),
					ht_td( { 'class' => 'dta' }, $email ),
					ht_utr(),

					ht_tr(),
					ht_td( { 'class' => 'shd' }, 'Username' ),
					ht_td( { 'class' => 'dta' }, $uname ),
					ht_utr(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Status' ),
					ht_td( 	{ 'class' => 'dta' }, 
							( ( $active ) ? 'Active' : 'Disabled' ) ),
					ht_utr(),

					ht_tr(), 
					ht_td( { 'class' => 'shd' }, 'Groups' ),
					ht_td( { 'class' => 'dta' } ), 
						ht_table(),

						ht_tr(),
						ht_td( { 'class' => 'shd' }, 'Member groups' ),
						ht_td( { 'class' => 'shd' }, 'Nonmember groups' ),
						ht_utr(),

						ht_tr(),
						ht_td( { 'class' => 'dta' } ),

					);

	my %groups; # Keep track of our groups.

	# Show the groups we are in.
	my $ath = db_query( $$site{dbh}, 'get groups in', 
						'SELECT group_id, name FROM auth_groups, ',
						'auth_group_members WHERE auth_groups.id = ',
						'auth_group_members.group_id AND user_id = ',
						sql_num( $id ), 'ORDER BY name' );

	while ( my ( $gid, $name ) = db_next( $ath ) ) {
		$groups{$gid} = 1;
		
		push( @lines, 	ht_a( "$$site{rootp}/user/$id/del/$gid", $name ),
						ht_br() );
	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @lines, 'Not a member of any groups' );
	}

	db_finish( $ath );

	push( @lines, ht_utd(), ht_td( { 'class' => 'dta' } ) );

	# Show the groups we are not in.
	my $bth = db_query( $$site{dbh}, 'get all groups', 
						'SELECT id, name FROM auth_groups ORDER BY name' );

	my $bcount = db_rowcount( $bth );

	while ( my ( $gid, $name ) = db_next( $bth ) ) {

		if ( defined $groups{$gid} ) {
			$bcount--;
			next;
		}

		push( @lines, 	ht_a( "$$site{rootp}/user/$id/add/$gid", $name ), 
						ht_br() );
	}

	push( @lines, 'Member of all groups' ) if ( $bcount < 1 );

	db_finish( $bth );

	return( @lines, ht_utd(), ht_utr(), ht_utable(),
					ht_utd(), ht_utr(), ht_utable(), ht_udiv() );
} # END $site->do_user
 
#-------------------------------------------------
# user_checkvals( $site, $in, $action )
#-------------------------------------------------
sub user_checkvals ($$$) {
	my ( $site, $in, $action ) = @_;

	my @errors;

	# Check last name
	if ( ! is_text( $in->{lname} ) ) {
		push( @errors, 'Users must have a last name.'. ht_br() );
	}

	# Check usersname
	if ( ( ! defined $in->{uname} ) || ( length( $in->{uname} ) < 5 ) ) {
		push( @errors, 	'The Login Name at least 5 characters.'. ht_br() );
	}
	else {
		if ( $in->{uname} =~ /\s/ ) {
			push( @errors, 'Usernames may not contain spaces.'. ht_br() );
		}
	}

	# Check email address.
	if ( ! is_email( $in->{email} ) ) {
		push( @errors, 'Users must have a valid email address.'. ht_br() );
	}

	if ( ( $action eq 'add' ) && 
		 ( ( ! defined $in->{pass} ) || ( ! defined $in->{cpass} ) || 
		 ( length( $in->{pass} ) < 6 ) ) )
	{
		push( @errors, 'Password must be at least (6) characters.'. ht_br() );
	}
	else {
		if ( ( $action eq 'edit' ) && 
			 ( defined $in->{pass} ) && ( defined $in->{cpass} ) && 
			 ( $in->{cpass} ne '' ) && ( $in->{pass} ne '' ) && 
			 ( length( $in->{pass} ) < 6 ) )
		{
			push( @errors, 	'Password must be at least (6) characters.'.
							ht_br() );
		}

		if ( ( defined $in->{pass} ) && ( defined $in->{cpass} ) && 
			 ( $$in{pass} ne $in->{cpass} ) )
		{
			push( @errors, 'Passwords do not match.'. ht_br() );
		}
	}

	if ( ( ( $action eq 'add' ) && ( defined $in->{uname} ) ) || 
		 ( ( $action eq 'edit' ) && ( defined $in->{uname} ) && 
		   ( defined $in->{ouname} ) && ( $in->{ouname} ne $in->{uname} ) ) )
	{
		my $uname = lc( $$in{uname} );

		my $sth = db_query( $$site{dbh}, 'Check username',
							'SELECT first_name, last_name FROM auth_users ',
							'WHERE user_name = ', sql_str( $uname ) );

		if ( db_rowcount( $sth ) > 0 ) {
			my ( $first, $last ) = db_next( $sth );	
			push( @errors,	qq!$uname is taken by: $first $last!. ht_br() );
		}

		db_finish( $sth );
	}

	return( @errors );
} # END user_checkvals

#-------------------------------------------------
# user_form( $site, $in, $action )
#-------------------------------------------------
sub user_form ($$$) {
	my ( $site, $in, $action ) = @_;

	my @groups;

	my $sth = db_query( $$site{dbh}, 'get groups', 
						'SELECT id, name FROM auth_groups ORDER BY name' );
	
	while ( my ( $id, $name ) = db_next( $sth ) ) {
		push( @groups, $id, $name );
	}

	db_finish( $sth );

	my @lines = (	ht_form_js( $$site{uri} ),	
					ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'First Name' ),
					ht_td( 	{ 'class' => 'dta' },	
							ht_input( 'fname', 'text', $in, 'size="30"' ),
							ht_help( $$site{help}, 'item', 'm:c:u:fname' ) ),
					ht_utr(),
	
					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Last Name' ),
					ht_td( 	{ 'class' => 'dta' }, 
							ht_input( 'lname', 'text', $in, 'size="30"' ),
							ht_help( $$site{help}, 'item', 'm:c:u:lname' ) ),
					ht_utr(),
					
					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Email' ),
					ht_td( 	{ 'class' => 'dta' }, 	
							ht_input( 'email', 'text', $in, 'size="30"' ),
							ht_help( $$site{help}, 'item', 'm:c:u:email' ) ),
					ht_utr(),
	
					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, 'Login Name' ),
					ht_td( 	{ 'class' => 'dta' }, 
							ht_input( 'uname', 'text', $in ),
							ht_input( 'ouname', 'hidden', $in ),
							ht_help( $$site{help}, 'item', 'm:c:u:uname' ) ),
					ht_utr() );
				
	if ( $action eq 'edit' ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, '&nbsp;' ),
						ht_td( 	{ 'class' => 'dta'  }, 
								ht_p(),
								q!To change a users password you must!,
								q!enter fill in the 'Password' and the!,
								q!'Password Confirm' boxes, otherwise the!,
								q!password for the user will not be changed.!,
								ht_up() ),
						ht_utr() );
	}
			
	return( @lines, 	

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Password' ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'pass', 'password', $in ),
					ht_help( $$site{help}, 'item', 'm:c:u:pass' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Password Confirm' ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'cpass', 'password', $in ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Groups' ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_select( 	'groups', scalar( @groups ) / 2, $in, 1, 
								'', @groups ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save'  ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END user_form

# EOF
1;

__END__

=head1 NAME 

KrKit::Control::Users - User Management 

=head1 SYNOPSIS

  use KrKit::Control::Users;
  
=head1 DESCRIPTION

This Handler manages users in the database to facilitate the use of that
information for authentication, autorization, and use in applications. 
This replaces the use of htpasswd for user management and puts more
information at the finger tips of the application.

=head1 APACHE

This is a sample of how the configuration of the handler might appear
in a random httpd.conf. It list all of the variables that the module
will use from the enviroment. These variables, being fairly common, are
document in KrKit::Framing(3), and KrKit::Appbase(3)

It is important to note that if you have authentication on you will not
be able to log in without a valid user account. The first user will need
to be added without Authen running, the KrKit libraries do not come with
any default accounts.

  <Location /admin/users >
    SetHandler 	perl-script

    PerlSetVar  SiteTitle       "User Management: "
    PerlSetVar  Frame           template;default.tp

    PerlSetVar  DatabaseType    Pg
    PerlSetVar  DatabaseServer  tick.sunflower.com
    PerlSetVar  DatabaseName    alchemy	
    PerlSetVar  DatabaseUser    dwarf	
    PerlSetVar  DatabasePw      w3bdb
    PerlSetVar  DatabaseCommit  off

    PerlHandler KrKit::Control::Users
  </Location>

=head1 DATABASE 

This is the auth_users table that is used by this module. It is also
used by the Authentication modules to verify usernames and passwords.
The passwords are ecrypted by the crypt(3) function in perl.

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

KrKit::Control(3), KrKit(3)

=head1 LIMITATIONS

The passwords for users are enrypted so they can not be seen at all. In
some situations this could be a very big problem.

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
