package KrKit::Xpander::Admin;

use strict; # It worked for your mother when you were a kid.

use Apache2::Request; 	# File Upload.
use DB_File;

use KrKit::Handler;
use KrKit::HTML qw(:all);
use KrKit::Validate;

############################################################
# Variables                                                #
############################################################
our @ISA = ( 'KrKit::Handler' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $site->_cleanup( $r )
#-------------------------------------------------
sub _cleanup {
	my ( $site, $r ) = @_;

	delete( $$site{dbx} );
	untie( $$site{dbhash} );

	return();
} # END $site->_cleanup

#-------------------------------------------------
# $site->_init( $r )
#-------------------------------------------------
sub _init {
	my ( $site, $r ) = @_;

	# Page specfic variables
	$$site{'uri'} 			= $r->uri;
	$$site{'rootd'} 		= $r->document_root;
	$$site{'rootp'} 		= $r->location;
	$$site{'contenttype'}	= 'text/html';
	$$site{'onpage_title'}	= '';
	$$site{'frame'}			= $r->dir_config( 'Frame' );
	$$site{'page_title'}	= $r->dir_config( 'SiteTitle' ) || '';

	# Not always used or set.
	$$site{'help'}			= $r->dir_config( 'HelpRoot' ) || '';

	# Date/Time formats.
	$$site{'fmt_d'}			= $r->dir_config( 'Date_Format' ) 		|| '%x';
	$$site{'fmt_t'}			= $r->dir_config( 'Time_Format' ) 		|| '%X';
	$$site{'fmt_dt'}		= $r->dir_config( 'DateTime_Format' ) 	|| '%x %X';

	# Specfic to Xpander
	$$site{'db_file'} 		= $r->dir_config( 'XpanderDB' );

	# Connect to the db_file database.	
	my %hash;
	$$site{'dbx'} 		= tie( 	%hash, 'DB_File', $$site{db_file},
								O_CREAT|O_RDWR, 0664, $DB_BTREE )
							or die "Could not open '$$site{db_file}': $!";

	$$site{'dbhash'}	= \%hash;

	return();
} # END $site->_init( $r )

#-------------------------------------------------
# $site->do_edit( $r, @p )
#-------------------------------------------------
sub do_edit {
	my ( $site, $r, @p ) = @_;

	my $in 		= $site->param( Apache2::Request->new( $r ) );

	$$site{page_title} 	.= 'Update';
	my $page 			= '/' . join( '/', @p );
	$in->{'file'} 		= $page;

	pop( @p ); # pop off the top.

	my $upone = join( '/', @p ); # make the root.

 	if ( defined $in->{'cancel'} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$upone" ) );
	}

	if ( ! ( my @err = $site->_checkvals( $in ) ) ) {
		$$site{dbhash}{$page} = $in->{'frame'}. "\cA". $in->{'title'};

		return( $site->_relocate( $r, "$$site{rootp}/main/$upone" ) );
	}
	else {
 		if ( my $entry = $$site{dbhash}{$page} ) {
			my ( $frame, $title ) = split( /\cA/, $entry ); 
			$in->{'frame'} = $frame if ( ! exists $in->{'frame'} );
			$in->{'title'} = $title if ( ! exists $in->{'title'} );
		}

		return( ( ( $r->method eq 'POST' ) ? @err : '' ), $site->_form( $in ) );
	}
} # END $site->do_edit

#-------------------------------------------------
# $site->do_delete( $r, @p )
#-------------------------------------------------
sub do_delete {
	my ( $site, $r, @p ) = @_;

	$$site{page_title} 	.= 'Update';
	my $in 				= $site->param( Apache2::Request->new( $r ) );
	my $page 			= '/' . join( '/', @p );		

	pop( @p );

	my $upone = join( '/', @p );

	if ( defined $in->{cancel} ) {
		return( $site->_relocate( $r, "$$site{rootp}/main/$upone" ) );
	}

	if ( ( defined $in->{yes} ) && ( $in->{yes} =~ /yes/i ) ) {
		delete( $$site{dbhash}{$page} );

		return( $site->_relocate( $r, "$$site{rootp}/main/$upone" ) );	
	}
	else {
		return( ht_form_js( $$site{uri} ),
				ht_input( 'yes', 'hidden', { 'yes', 'yes' } ), 

				ht_div( { 'class' => 'box' } ),
				ht_table(),

				ht_tr(),
				ht_td( 	{ 'class' => 'dta' }, 
						qq!Delete the entry for "$page"?! ),
				ht_utr(),
	
				ht_tr(),
				ht_td( { 'class' => 'rshd' }, 
						ht_submit( 'submit', 'Remove'  ),
						ht_submit( 'cancel', 'Cancel' ) ),
				ht_utr(),
				ht_utable(),
				ht_udiv(),
				ht_uform() );
	}
} # END $site->do_delete

#-------------------------------------------------
# $site->do_main( $r, @p )
#-------------------------------------------------
# Show the tree, navigate it. Pop up for pages
# that are not a directory so we can view it 
# when we are editing it.
#-------------------------------------------------
sub do_main {
	my ( $site, $r, @p ) = @_;

	# Make some of the links for the page.
	my $base 	= '/'. join( '/', @p ) . '/';
	pop( @p );
	my $up 		= '/'. join( '/', @p ) . '/';

	$base 		=~ s/\/\//\//g;
	$up 		=~ s/\/\//\//g;
	my $dir 	= "$$site{rootd}$base";
	my $upone 	= "$$site{rootp}/main$up";

	my @lines = ( 	q!<script><\!--!,
					q! function showcontent(d) { !,
					q! window.open(d, 'Shortcut' ); } !,
					q!//--> </script>!,

					ht_div( { 'class' => 'box' } ),
					ht_table(),

					ht_tr(),
					ht_td( 	{ 'class' => 'shd' }, $base ),
					ht_td( 	{ 'class' => 'shd' }, 'Frame' ),
					ht_td( 	{ 'class' => 'shd' }, 'Title' ),
					ht_td( 	{ 'class' => 'rshd' },
							'[', ht_a ( $upone, 'Up one Directory' ), ']' ),
					ht_utr() );

	die( "Can't open $dir: $!" ) if ( ! opendir( DIR, $dir ) );

	for my $file ( sort( readdir( DIR ) ) ) {
		next if ( $file =~ /^\.+.*$/ );
		next if ( $file =~ /^CVS$/ );

		my @link;

		if ( -d "$dir/$file" ) {
			push( @link, ht_a( 	"$$site{rootp}/main$base$file", 
								"$file/" ) );
		}
		else {
			push( @link, ht_a( "javascript://", $file,  
								"OnClick=\"showcontent('$base$file')\"" ) );
		}

		push( @lines, 	ht_tr(),
						ht_td( { 'class' => 'dta' }, @link ) );
			
		if ( my $entry = $$site{dbhash}{"$base$file"} ) {
			my ( $frame, $title ) = split( "\cA", $entry ); 

			push( @lines, 	ht_td( { 'class' => 'dta' }, "&middot $frame" ),
							ht_td( { 'class' => 'dta' }, "$title &nbsp;" ),
							ht_td( { 'class' => 'rdta' }, 
								'[',
								ht_a( "$$site{rootp}/edit$base$file", 'Edit'), 
								"|",
								ht_a( 	"$$site{rootp}/delete$base$file", 
										'Remove' ), ']' ) );
		}	
		else {
			push( @lines, 	ht_td( 	{ 'class' => 'dta', 'colspan' => '2'}, 
									'&nbsp;' ),
							ht_td( 	{ 'class' => 'rdta' },
									'[',
									ht_a( 	"$$site{rootp}/edit$base$file", 
											'Add' ), ']' ) );
		}

		push( @lines, ht_utr() );	
 	}

	closedir( DIR );

	return( @lines, ht_utable(), ht_udiv() );
} # END $site->do_main

#-------------------------------------------------
# $site->_checkvals( $in )
#-------------------------------------------------
sub _checkvals ($$) {
	my ( $site, $in ) = @_;

	my @errors;

	if ( ! is_text( $in->{'frame'} ) ) {
		push( @errors, 'Please enter a frame.' );
	}

	if ( ! is_text( $in->{'title'} ) ) {
		push( @errors, 'You must select a title.' );
	}

	if ( @errors ) {
		return( ht_div( { 'class' => 'error' }, ht_ul( {}, @errors ) ) );
	}
	else {
		return();
	}
} # END $site->_checkvals

#-------------------------------------------------
# $site->_form ( $site, $in )
#-------------------------------------------------
sub _form ($$) {
	my ( $site, $in ) = @_;

	return(	ht_form_js( $$site{uri} ),
			ht_div( { 'class' => 'box' } ),
			ht_table(),

			ht_tr(),
			ht_td( { 'class' => 'shd' }, 'Page' ),
			ht_td( { 'class' => 'dta' }, $in->{file} ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Frame' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'frame', 'text', $in ),
					ht_help( $$site{help}, 'item', 'm:x:a:frame' ) ),
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'class' => 'shd' }, 'Page Title' ),
			ht_td( 	{ 'class' => 'dta' },
					ht_input( 'title', 'text', $in ),
					ht_help( $$site{help}, 'item', 'm:x:a:page' ) ),	
			ht_utr(),

			ht_tr(),
			ht_td( 	{ 'colspan' => 2, 'class' => 'rshd' }, 
					ht_submit( 'submit', 'Save'  ),
					ht_submit( 'cancel', 'Cancel' ) ),
			ht_utr(),

			ht_utable(),
			ht_udiv(),
			ht_uform() );
} # END $site->_form 

# EOF
1;

__END__

=head1 NAME 

KrKit::Xpander::Admin - Xpander's Admin Interface.

=head1 SYNOPSIS

  use KrKit::Xpander::Admin;

=head1 DESCRIPTION

This is the frontend for to setup how the xpander works for flat files.
It allows the users to change the framing of a file on the fly without
requireing a server restart. 

=head1 APACHE

This is a sample setup for the admin interface. The XpanderDB should 
be the same setting as that used for the Xpander itself, see C<Xpander(3)>.
The frame specified is the frame that wraps the xpander admin interface
and does not influance the files being assigned frames at all.

  <Location /Admin/Xpander >
    SetHandler  perl-script

    PerlSetVar  SiteTitle   Xpander	
	PerlSetVar  Frame       Frame::SomeFrame
    PerlSetVar  XpanderDB   /home/httpd/dangermouse.db

    PerlHandler KrKit::Xpander::Admin
  </Location>

=head1 DATABASE 

There is no database directly relied upon by this module. It only deals
with the flat database, which is a Berkley DB file. The C<XpanderDB> 
variable specifies where that file is located so that a single site
may have many differenct DB files responsible for different sections
of the site.

=head1 SEE ALSO

KrKit::Xpander(3), KrKit(3)

=head1 LIMITATIONS

The admin interface for the xpander applies only to flat files and 
can not be used to determine the frame for applications, they must 
still be defined in the apache configuration.

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
