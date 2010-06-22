package KrKit::Helper::Category;

use strict;

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
# $site->_init( $r );
#-------------------------------------------------
sub _init {
	my ( $site, $r ) = @_; 

	$site->SUPER::_init( $r );

	$$site{'rooti'}	= $r->dir_config( 'Help_Item_Root' ) || '';

	return();
} # END _init

#-------------------------------------------------
# category_checkvals( $in )
#-------------------------------------------------
sub category_checkvals {
	my $in = shift;

	my @errors = ();

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a category name.'. ht_br() );
	}

	if ( ! is_ident( $in->{ident} ) ) {
		push( @errors, 'Enter an ident.'. ht_br() );
	}
	
	if ( ! is_text( $in->{frame} ) ) {
		push( @errors, 'Please enter a frame.'. ht_br() );
	}

	return( @errors );
} # END category_checkvals

#-------------------------------------------------
# category_form( $site, $in )
#-------------------------------------------------
sub category_form {
	my ( $site, $in ) = @_;

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name' ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'name', 'text', $in, 'SIZE=40' ),
					ht_help( $$site{help}, 'item', 'm:h:c:name' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'ident', 'text', $in, 'SIZE=20' ),
					ht_help( $$site{help}, 'item', 'm:h:c:ident' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Frame' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'frame', 'text', $in, 'SIZE=20' ),
					ht_help( $$site{help}, 'item', 'm:h:c:frame' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save'  ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END category_form

#-------------------------------------------------
# $site->do_add( $r, $pid )
#-------------------------------------------------
sub do_add {
	my ( $site, $r, $pid ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Add Category';
	$pid 				= 0 if ( ! is_number( $pid ) );
 
 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) );
	}

	if ( ! ( my @errors = category_checkvals( $in ) ) ) {

		db_run( $$site{dbh}, 'insert a new category',
				sql_insert( 'help_categories', 
							'parent_id'	=> sql_num( $pid ),
							'name'		=> sql_str( $in->{name} ),
							'ident'		=> sql_str( $in->{ident} ),
							'frame'		=> sql_str( $in->{frame} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, category_form( $site, $in ) );
		}
		else {
			return( category_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $pid, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $pid, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete Category';

	return( 'Invalid id.' ) 			if ( ! is_number( $pid ) );
	return( 'Invalid category id.' ) 	if ( ! is_number( $id ) );
 
 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) )
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		my $sth = db_query( $$site{dbh}, 'find children', 
							'SELECT count(id) FROM help_categories WHERE ',
							'parent_id = ', sql_num( $id ) );

		my $count = db_next( $sth );

		db_finish( $sth );

		if ( is_number( $count ) && $count > 0 ) {
			return('Can not remove category, children must be deleted first.');
		}

		db_run( $$site{dbh}, 'Delete a category.', 
				'DELETE FROM help_categories WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) );
	}
	else {
		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table(),
				ht_tr(),
				ht_td( { 'class' => 'dta' }, 
						q!Other applications may depend on !,
						q!this category id being in the table, should we !,
						q!really delete it?! ),
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
} # END $site->do_delete

#-------------------------------------------------
# $site->do_edit( $r, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $pid, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Update Category';
	$pid 				= 0 if ( ! is_number( $pid ) );

	return( 'Invalid id.' ) if ( ! is_number( $id ) );

 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) );
	}

	if ( ! ( my @errors = category_checkvals( $in ) ) ) {

		db_run( $$site{dbh}, 'insert a new category',
				sql_update( 'help_categories', 'WHERE id = '. sql_num( $id ),
							'name'		=> sql_str( $in->{name} ),
							'ident'		=> sql_str( $in->{ident} ),
							'frame'		=> sql_str( $in->{frame} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$pid" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values', 
							'SELECT ident, frame, name FROM help_categories', 
							'WHERE id = ', sql_num( $id ) );

		while ( my ( $ident, $frame, $name ) = db_next( $sth ) ) {
			$in->{name} 	= $name 	if ( ! defined $in->{name} );
			$in->{ident} 	= $ident 	if ( ! defined $in->{ident} );
			$in->{frame} 	= $frame 	if ( ! defined $in->{frame} );
		}
		
		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, category_form( $site, $in ) );
		}
		else {
			return( category_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r )
#-------------------------------------------------
sub do_main {
	my ( $site, $r, $pid ) = @_;

	$$site{page_title} 	.= 'Listing';
	$pid 				= 0 if ( ! is_number( $pid ) );
	my $root			= '';

	if ( $pid == 0 ) {
		$root = 'Top of the Tree';
	}
	else {
		# Look up the name.
		my $sth = db_query( $$site{dbh}, 'find name, parent', 
							'SELECT parent_id, name FROM help_categories ',
							'WHERE id = ', sql_num( $pid ) );

		my ( $p_id, $name ) = db_next( $sth );

		db_finish( $sth );

		$root = join( ' ', ht_a( "$$site{rootp}/main/$p_id", $name ) );
	}

	my @lines=( ht_div( { 'class' => 'box' } ),
				ht_table( ),
				ht_tr(),
				ht_td( 	{ 'class' => 'hdr', 'colspan' => '3' }, $root ),
				ht_td( 	{ 'class' => 'rhdr' }, 
						'[',
						ht_a( "$$site{rootp}/add/$pid", 'Add Category' ), '|',
 						ht_a( "$$site{rooti}/main/$pid", 'Items' ), ']' ),
				ht_utr(),
				
				ht_tr(),
				ht_td( { 'class' => 'shd' }, 'Name' ),
				ht_td( { 'class' => 'shd' }, 'Ident' ),
				ht_td( { 'class' => 'shd' }, 'Children' ),
				ht_td( { 'class' => 'shd' }, '&nbsp;' ),
				ht_utr() );

	my $sth = db_query( $$site{dbh}, 'get listing', 
						'SELECT id, ident, name FROM help_categories',
						'WHERE parent_id = ', sql_num( $pid ) );

	while( my ( $id, $ident, $name ) = db_next( $sth ) ) {

		# count children.
		my $ath = db_query( $$site{dbh}, 'get child count', 
							'SELECT count(id) FROM help_categories WHERE ',
							'parent_id = ', sql_num( $id ) );

		my $count = db_next( $ath );

		db_finish( $ath );

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' },
								ht_a( "$$site{rootp}/main/$id", $name ) ),
						ht_td( 	{ 'class' => 'dta' }, $ident ),
						ht_td( 	{ 'class' => 'dta' }, $count ),
						ht_td( 	{ 'class' => 'rdta' },
								'[',
								ht_a( "$$site{rootp}/items/main/$id",'Items'),
								'|',
								ht_a( "$$site{rootp}/edit/$pid/$id", 'Edit' ),
								'|', 
								ht_a( 	"$$site{rootp}/delete/$pid/$id", 
										'Delete' ), ']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) { 
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'colspan' => '5', 'class' => 'cdta' },
								'No categories found' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

# EOF
1;

__END__

=head1 NAME 

KrKit::Helper::Category - Help Category management.

=head1 SYNOPSIS

  use KrKit::Helper::Category;

=head1 DESCRIPTION

This is the help system's administration interface. This module
maintains the categories of help. The Items are maintained by
KrKit::Helper::Category::Items.

=head1 APACHE

Here is a sample configuration for this module. It will also listen to
any configuration from the standard handler as that's what it uses.

  <Location /admin/help >
    SetHandler 	perl-script

    PerlSetVar 	SiteTitle 	"Help Subsystem: "

    PerlHandler KrKit::Helper::Category
  </Location>

=head1 DATABASE

This is the primary table that this module manipulates.

  create table "help_categories" (
    "id"     int4 primary key default nextval('help_categories_seq') NOT NULL,
    "parent_id" int4,
    "ident"     varchar,
    "name"      varchar
  );

=head1 SEE ALSO

KrKit::Helper(3), KrKit(3)

=head1 LIMITATIONS

When deleteing a category all of it's children must be removed first, no
this will not be fun or easy as it's probably a really bad idea to
delete it in the first place.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
