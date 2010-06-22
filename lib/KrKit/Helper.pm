package KrKit::Helper;

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
# category_links( $site, $catid ) 
#-------------------------------------------------
sub category_links {
	my ( $site, $catid ) = @_;

	return() if ( ! is_number( $catid ) );

	my @cats;

	my $sth = db_query( $$site{dbh}, 'get cat name, ident, parent',
						'SELECT parent_id, ident, name FROM ',
						'help_categories WHERE id = ', sql_num( $catid ) );

	while ( my( $pid, $ident, $name ) = db_next( $sth ) ) {
		push( @cats, category_links( $site, $pid ) );

		if ( scalar( @cats ) > 0 ) {
			push( @cats, '&nbsp;->&nbsp;' );
		}

		push( @cats,  ht_a( "$$site{rootp}/category/$ident", $name ) );
	}

	db_finish( $sth );

	return( @cats );
} # END category_links

#-------------------------------------------------
# $site->do_category( $r, $cat_ident )
#-------------------------------------------------
sub do_category {
	my ( $site, $r, $cident ) = @_;

	return( 'Invalid ident' ) if ( ! is_ident( $cident ) );

	my $sth = db_query( $$site{dbh}, 'find category', 
						'SELECT id, frame, name FROM help_categories ',
						'WHERE ident = ', sql_str( $cident ) );

	my ( $cid, $cframe, $cname ) = db_next( $sth );
	
	db_finish( $sth );

	if ( is_text( $cframe ) ) {
		$$site{frame} = $cframe if ( $cframe !~ /^auto$/ );
	}

	my ( @items, @kids );

	my $ath = db_query( $$site{dbh}, 'find this categories items.',
						'SELECT ident, name FROM help_items WHERE ',
						"category_id = '$cid' ORDER BY name" );
	
	while ( my ( $ident, $name ) = db_next( $ath ) ) {
		push( @items, ht_a( "$$site{rootp}/item/$ident", $name ), ht_br() );
	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @items, 'No help items for this category.'. ht_br() );
	}

	db_finish( $ath );

	my $bth = db_query( $$site{dbh}, 'find child categories', 
						'SELECT ident, name FROM help_categories WHERE ',
						'parent_id = ', sql_num( $cid ) );

	while ( my ( $ident, $name ) = db_next( $bth ) ) {
		push( @kids, ht_a( "$$site{rootp}/category/$ident", $name ), ht_br() );
	}

	if ( db_rowcount( $bth ) < 1 ) {
		push( @kids, 'No sub categories for this category.' );
	}

	db_finish( $bth );

	return( ht_table( { 'border' 		=> '0', 
						'width'			=> '100%',
						'cellpadding' 	=> '2',
						'cellspacing' 	=> '2' } ),

			ht_tr(),
			ht_td( { colspan => '2' }, ht_b( "'$cname' help items:" ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { width => '5%' }, '&nbsp;' ),
			ht_td( {},	@items, '<hr noshade width="40%">' ),
			ht_utr(),

			ht_tr(),
			ht_td( {colspan => '2', }, 'Related Categories:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( { }, category_links( $site, $cid ) ),
			ht_utr(),

			ht_tr(),
			ht_td( {colspan => '2', }, 'Sub Categories:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( { }, @kids ),
			ht_utr(),

			ht_utable()	);
} # END $site->do_category

#-------------------------------------------------
# $site->do_item( $r, $item_ident )
#-------------------------------------------------
sub do_item {
	my ( $site, $r, $iident ) = @_;

	return( 'Invalid ident' ) if ( ! is_ident( $iident ) );

	my $sth = db_query( $$site{dbh}, 'find help', 
						'SELECT category_id, created, name, content FROM ',
						'help_items WHERE ident = ', sql_str( $iident ) );

	my ( $catid, $date, $name, $content ) = db_next( $sth );
 
 	if ( db_rowcount( $sth ) < 1 ) {
		return( '<br><br><center><b>No item found.</b></center><br><br>' );
	}

	db_finish( $sth );

	my $ath = db_query( $$site{dbh}, 'find cat', 
						'SELECT ident, frame, name FROM help_categories',
						'WHERE id = ', sql_num( $catid ) );

	my ( $catident, $cframe, $catname ) = db_next( $ath );

	db_finish( $ath );

	if ( is_text( $cframe ) ) {
		$$site{frame} = $cframe if ( $cframe !~ /^auto$/ );
	}

	return( ht_table( { 'border' 		=> '0', 
						'width'			=> '100%',
						'cellpadding' 	=> '2',
						'cellspacing' 	=> '2' } ),

			ht_tr(),
			ht_td( { colspan => '2' }, ht_b( $name ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { width => '5%' }, '&nbsp;' ),
			ht_td( {},	ht_p(), $content, ht_up(),
						'<hr noshade width="40%">' ),
			ht_utr(),

			ht_tr(),
			ht_td( {colspan => '2', }, 'Last updated:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( {colspan => '2', }, $date ),
			ht_utr(),

			ht_tr(),
			ht_td( {colspan => '2', }, 'Current Category:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( 	{colspan => '2', }, 
					ht_a( "$$site{rootp}/category/$catident", $catname ) ),
			ht_utr(),


			ht_tr(),
			ht_td( {colspan => '2', }, 'Related Categories:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( { }, category_links( $site, $catid ) ),
			ht_utr(),

			ht_utable()	);
} # END $site->do_item

#-------------------------------------------------
# $site->do_main( $r )
#-------------------------------------------------
sub do_main {
	my ( $site, $r ) = @_;

	my ( @items, @kids );

	my $ath = db_query( $$site{dbh}, 'find this categories items.',
						'SELECT ident, name FROM help_items WHERE ',
						'category_id = ', sql_num( 0 ), ' ORDER BY name' );
	
	while ( my ( $ident, $name ) = db_next( $ath ) ) {
		push( @items, ht_a( "$$site{rootp}/item/$ident", $name ), ht_br() );
	}

	if ( db_rowcount( $ath ) < 1 ) {
		push( @items, 'No help items for this category.'. ht_br() );
	}

	db_finish( $ath );

	my $bth = db_query( $$site{dbh}, 'find child categories', 
						'SELECT ident, name FROM help_categories ',
						'WHERE parent_id = ', sql_num( 0 ) );

	while ( my ( $ident, $name ) = db_next( $bth ) ) {
		push( @kids, ht_a( "$$site{rootp}/category/$ident", $name ), ht_br() );
	}

	if ( db_rowcount( $bth ) < 1 ) {
		push( @kids, 'No sub categories for this category.' );
	}

	db_finish( $bth );

	return( ht_table( { 'border' 		=> '0', 
						'width'			=> '100%',
						'cellpadding' 	=> '2',
						'cellspacing' 	=> '2' } ),

			ht_tr(),
			ht_td( { colspan => '2' }, ht_b( "Top level help items:" ) ),
			ht_utr(),

			ht_tr(),
			ht_td( { width => '5%' }, '&nbsp;' ),
			ht_td( {},	@items, '<hr noshade width="40%">' ),
			ht_utr(),

			ht_tr(),
			ht_td( {colspan => '2', }, 'Sub Categories:' ),
			ht_utr(),

			ht_tr(),
			ht_td( { }, '&nbsp;' ),
			ht_td( { }, @kids ),
			ht_utr(),

			ht_utable()	);
} # END $site->do_main

# EOF
1;

__END__

=head1 NAME 

KrKit::Helper - Help sub-system

=head1 SYNOPSIS

  use KrKit::Helper;

=head1 DESCRIPTION

This module is the head of the help system. It is also the viewer for
the help system.

=head1 APACHE

This is an example of the apache configuration for this module, it will
also listen to the PerlSetVar's from KrKit(3).

  <Location /help >
    SetHandler  perl-script
    PerlHandler KrKit::Helper

    PerlSetVar  Frame template;help.tp
  </Location>

=head1 DATABASE

These are the two tables that the help pages are generated from. This
module only selects from these tables.

  create table "help_items" (
    "id"           int4 primary key default nextval('help_items_seq') NOT NULL,
    "category_id"  int4,
    "ident"        varchar, /* Needs to be unique */
    "created"      timestamp,
    "name"         varchar,
    "content"      text
  );

  create table "help_categories" (
    "id"       int4 primary key default nextval('help_categories_seq') NOT NULL,
    "parent_id" int4,
    "ident"    varchar, /* Needs to be unique */
    "name"     varchar
  );

=head1 MODULES

=over 4

=item KrKit::Helper::Category

This is the help system's administration interface. This module
maintains the categories of help. The Items are maintained by
KrKit::Helper::Category::Items.

=item KrKit::Helper::Category::Items

This is part of the help system adminstration interface. This module
maintains the individual help items. 

=back

=head1 SEE ALSO

KrKit(3)

=head1 LIMITATIONS

Limitations are listed in the modules they apply to.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
