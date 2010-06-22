package KrKit::Helper::Category::Items;

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

	$$site{'rootc'}	= $r->dir_config( 'Help_Category_Root' ) || '';

	return();
} # END _init

#-------------------------------------------------
# $site->do_add( $r, $catid )
#-------------------------------------------------
sub do_add {
	my ( $site, $r, $catid ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Add Item';
	$catid 				= 0 if ( ! is_number( $catid ) );
 
 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) );
	}

	if ( ! ( my @errors = item_checkvals( $in ) ) ) {

		$in->{content} =~ s/(\r\n|\n)/<br>/g;

		db_run( $$site{dbh}, 'insert a new item',
				sql_insert( 'help_items', 
							'category_id'	=> sql_num( $catid ),
							'ident'			=> sql_str( $in->{ident} ),
							'name'			=> sql_str( $in->{name} ),
							'created'		=> sql_str( 'now' ),
							'content'		=> sql_str( $in->{content} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) );
	}
	else {
		if ( $r->method eq 'POST' ) {
			return( @errors, item_form( $site, $in ) );
		}
		else {
			return( item_form( $site, $in ) );
		}
	}
} # END $site->do_add

#-------------------------------------------------
# $site->do_delete( $r, $catid, $id, $yes )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, $catid, $id, $yes ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Delete Category';

	return( 'Invalid category id.' ) 	if ( ! is_number( $catid ) );
	return( 'Invalid item id.' ) 		if ( ! is_number( $id ) );
 
 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) )
	}

	if ( ( defined $yes ) && ( $yes eq 'yes' ) ) {

		db_run( $$site{dbh}, 'Delete an item.', 
				'DELETE FROM help_items WHERE id = ', sql_num( $id ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) );
	}
	else {
		return( ht_form_js( "$$site{uri}/yes" ), 
				ht_div( { 'class' => 'box' } ),
				ht_table(),
				ht_tr(),
				ht_td( { 'class' => 'dta' }, 
						q!Other applications may depend on !,
						q!this item being in the table, should we !,
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
# $site->do_edit( $r, $catid, $id )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, $catid, $id ) = @_;

	my $in 				= $site->param( Apache2::Request->new( $r ) );
	$$site{page_title} 	.= 'Update Item';
	$catid 				= 0 if ( ! is_number( $catid ) );

	return( 'Invalid item id.' ) if ( ! is_number( $id ) );
 
 	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) );
	}

	if ( ! ( my @errors = item_checkvals( $in ) ) ) {

		$in->{content} =~ s/(\r\n|\n)/<br>/g;

		db_run( $$site{dbh}, 'insert a new item',
				sql_update( 'help_items', 'WHERE id = '. sql_num( $id ),
							'ident'		=> sql_str( $in->{ident} ),
							'name'		=> sql_str( $in->{name} ),
							'created'	=> sql_str( 'now' ),
							'content'	=> sql_str( $in->{content} ) ) );

		db_commit( $$site{dbh} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$catid" ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get old values', 
							'SELECT ident, name, created, content FROM ',
							'help_items WHERE id = ', sql_num( $id ) );

		while ( my ( $ident, $name, $date, $content ) = db_next( $sth ) ) {
			$in->{date}		= $date;
			$in->{ident} 	= $ident 	if ( ! defined $in->{ident} );
			$in->{name} 	= $name 	if ( ! defined $in->{name} );

			if ( ! defined $in->{content} ) {
				$content 		=~ s/<br>/\n/g;
				$in->{content} 	= $content;
			}
		}

		db_finish( $sth );

		if ( $r->method eq 'POST' ) {
			return( @errors, item_form( $site, $in ) );
		}
		else {
			return( item_form( $site, $in ) );
		}
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_main( $r, $catid )
#-------------------------------------------------
sub do_mains {
	my ( $site, $r, $catid ) = @_;

	$$site{page_title} 	.= 'List Items';
	$catid 				= 0 if ( ! is_number( $catid ) );
	my @cat_ref;

	# Display category name and ident.
	if ( $catid == 0 ) {
		push( @cat_ref, ht_a( "$$site{rootc}/main/$catid", 'Top Of Tree' ) );
	}
	else {
		my $sth = db_query( $$site{dbh}, 'get cat name/ident', 
							'SELECT ident, name FROM help_categories ',
							'WHERE id = ', sql_num( $catid ) ); 

		my ( $catident, $catname ) = db_next( $sth );

		db_finish( $sth );

		push( @cat_ref, ht_a( 	"$$site{rootc}/main/$catid",
								"$catname ($catident)" ) );
	}

	my @lines=( ht_div( { 'class' => 'box' } ),
				ht_table(),

				ht_tr(),
				ht_td( 	{ 'colspan' => '3', 'class' => 'hdr' }, @cat_ref ),
				ht_td( 	{ 'class' => 'rhdr' }, 
						'[',ht_a( "$$site{rootp}/add/$catid", 'Add Item' ),']'),
				ht_utr(),
				
				ht_tr(),
				ht_td( { 'class' => 'shd' }, 'Name' ),
				ht_td( { 'class' => 'shd' }, 'Ident' ),
				ht_td( { 'class' => 'shd' }, 'Updated' ),
				ht_td( { 'class' => 'shd' }, '&nbsp;' ),
				ht_utr() );

	# Show ident/title for all help items.
	my $sth = db_query( $$site{dbh}, 'get items listing', 
						'SELECT id, ident, name, created FROM help_items ',
						'WHERE category_id = ', sql_num( $catid ), 
						'ORDER BY name, created' );
	
	while ( my ( $id, $ident, $name, $made ) = db_next( $sth ) ) {

		push( @lines, 	ht_tr(),
						ht_td( 	{ 'class' => 'dta' }, 
								$name,
								ht_help( $$site{help}, 'item', $ident ) ),
						ht_td( 	{ 'class' => 'dta' }, $ident ),
						ht_td( 	{ 'class' => 'dta' }, $made ),
						ht_td( 	{ 'class' => 'rdta' }, 
								'[', 
								ht_a( "$$site{rootp}/edit/$catid/$id", 'Edit' ),
								'|',
								ht_a( 	"$$site{rootp}/delete/$catid/$id",
										'Delete' ), ']' ),
						ht_utr() );
	}

	if ( db_rowcount( $sth ) < 1 ) {
		push( @lines, 	ht_tr(),
						ht_td( 	{ 'colspan' => '4', 'class' => 'cdta' }, 
								'No Items for this Category.' ),
						ht_utr() );
	}

	db_finish( $sth );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# item_checkvals( $in )
#-------------------------------------------------
sub item_checkvals {
	my $in = shift;

	my @errors;

	if ( ! is_text( $in->{name} ) ) {
		push( @errors, 'Enter a name / title.'. ht_br() );
	}

	if ( ! is_ident( $in->{ident} ) ) {
		push( @errors, 'Enter an ident.'. ht_br() );
	}

	if ( ! is_text( $in->{content} ) ) {
		push( @errors, 'Enter some content.'. ht_br() );
	}

	return( @errors );
} # END item_checkvals

#-------------------------------------------------
# item_form( $site, $in )
#-------------------------------------------------
sub item_form {
	my ( $site, $in ) = @_;

	my @updated = ();

	if ( defined $in->{date} ) {
		push( @updated, ht_tr(),
						ht_td( { 'class' => 'shd' }, 'Updated' ),
						ht_td( { 'class' => 'dta' }, $in->{date} ),
						ht_utr() );
	}

	return( ht_form_js( $$site{uri} ),	
			ht_div( { 'class' => 'box' } ),
			ht_table(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Name / Title' ),
			ht_td( 	{ 'class' => 'dta' }, 	
					ht_input( 'name', 'text', $in, 'SIZE=40' ),
					ht_help( $$site{help}, 'item', 'm:h:c:i:name' ) ),
			ht_utr(),

			@updated,

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Ident' ),
			ht_td( 	{ 'class' => 'dta' }, 
					ht_input( 'ident', 'text', $in, 'SIZE=20' ),
					ht_help( $$site{help}, 'item', 'm:h:c:i:ident' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Content' ),
			ht_td( 	{ 'class' => 'dta' },  
					ht_input( 	'content', 'textarea', $in, 
								'cols="40" rows="10"' ),
					ht_help( $$site{help}, 'item', 'm:h:c:i:content' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => '2', 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save'  ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END item_form

# EOF
1;

__END__

=head1 NAME 

KrKit::Helper::Category::Items - Help Item Management.

=head1 SYNOPSIS

  use KrKit::Helper::Category::Items;

=head1 DESCRIPTION

This is part of the help system adminstration interface. This module
maintains the individual help items. 

=head1 APACHE

Here is a sample configuration for this module. It will also listen to
any configuration from the standard handler as that's what it uses.

  <Location /admin/help/items >
    SetHandler 	perl-script

    PerlSetVar 	SiteTitle 	"Help Subsystem: "

    PerlSetVar	MasterRoot	/admin/help

    PerlHandler KrKit::Helper::Category::Items
  </Location>

=head1 DATABASE

This is the primary table that this module manipulates.

  create table "help_items" (
    "id"           int4 primary key default nextval('help_items_seq') NOT NULL,
    "category_id"  int4,
    "ident"        varchar, /* Needs to be unique */
    "created"      timestamp,
    "name"         varchar,
    "content"      text
  );


=head1 SEE ALSO

KrKit::Helper::Cateory(3), KrKit::Helper(3), KrKit(3)

=head1 LIMITATIONS

This module depends in a most dependant way on the
KrKit::Helper::Category module and is entirely useless without it.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
