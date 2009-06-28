package KrKit::Xpander;

use strict; # It worked for your mother when you were a kid.

use Apache2::Const -compile => qw(:common);
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::SubRequest;

use DB_File;

use KrKit::AppBase;
use KrKit::Framing;

############################################################
# Variables                                                #
############################################################
sub get_page ($$); # Prototype this function.

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# get_page( $site, $uri )
#-------------------------------------------------
sub get_page ($$) {
	my ( $site, $uri ) = @_;

	# Run through the url till we find something, or till we hit root.
	my $page = '';	

	if ( ! ( $page = $$site{dbhash}{$uri} ) ) {
		my @p = split( '/', $uri ); # rip off one and pass it along.
		pop( @p );
		
		# Look till we find something.
		$page = ( scalar( @p ) < 1 ) ? '' : get_page( $site, join( '/', @p ) );
	}

	return( $page );
} # END get_page

#-------------------------------------------------
# setup_db( $r, $site ) 
#-------------------------------------------------
sub setup_db ($$) {
	my ( $r, $site ) = @_;

	my %hash;

	# Opens up the db file for us to use. 
	$$site{dbx} = tie( 	%hash, 'DB_File', $$site{db_file},
						O_CREAT|O_RDWR, 0664, $DB_BTREE )
						or die "Could not open '$$site{db_file}': $!";

	return( \%hash );
} # END setup_db 

######################################################################
# Main Execution Begins Here                                         #
######################################################################
sub handler : method {
	my ( $class, $r ) = @_;

	my $site 			= {};	# Set up the specific directory variables.
	$$site{'uri'} 		= $r->uri;
	$$site{'db_file'} 	= $r->dir_config( 'XpanderDB' );
	$$site{'xpandall'}	= $r->dir_config( 'XpanderAllFiles' ) 	|| '';
	$$site{'page_title'}= $r->dir_config( 'SiteTitle' ) 		|| '';
	$$site{'frame'}		= $r->dir_config( 'Frame' );
	$$site{'fmt_d'}		= $r->dir_config( 'Date_Format' ) 		|| '%x';
	$$site{'fmt_t'}		= $r->dir_config( 'Time_Format' ) 		|| '%X';
	$$site{'fmt_dt'}	= $r->dir_config( 'DateTime_Format' ) 	|| '%x %X';

	$$site{'dbhash'} 	= setup_db( $r, $site );

	my $uri = $$site{uri};
	$uri =~ s/\/\//\//g;

	# If it's a 404 return it.
	if ( ! ( -e ( $r->lookup_uri( $$site{uri} ) )->filename ) ) {
		return( Apache2::Const::DECLINED );
	}

	if ( ! ( -r ( $r->lookup_uri( $$site{uri} ) )->filename ) ) {
		return( Apache2::Const::DECLINED );
	}

	# Allow people to set site wide frames for ease.
	if ( ( $$site{xpandall} !~ /on/i ) || ( ! defined $$site{frame} ) ) {
		if ( my $page_info = get_page( $site, $uri ) ) {
			( $$site{frame}, $$site{page_title} ) = split( "\cA", $page_info );

			return(Apache2::Const::DECLINED) if ($$site{frame} eq 'No::Frame');
		}
		else {
			return( Apache2::Const::DECLINED );	
		}
	}

	delete $$site{dbx};
	untie $$site{dbhash};

	eval {
		my $filename 		= ( $r->lookup_uri( $r->uri ) )->filename;
		my $frame 			= appbase_get_frame( $r, $$site{frame} );
		$$site{body_file} 	= $filename;
		
		$r->content_type( 'text/html' );
		$r->no_cache( 1 ) if ( $r->dir_config( 'NoCache' ) );

		$frame->send( $r, $site );
	};

	$r->print( "Error: $@" ) if ( $@ );

	return( Apache2::Const::OK );
} # END $self->handler

# EOF
1;

__END__

=head1 NAME 

KrKit::Xpander - Expands content into a frame.

=head1 SYNOPSIS

  use KrKit::Xpander;

=head1 DESCRIPTION

This module, handler, relies on a database file to expand files into a frame
if the frame is defined. There is also the ability to specify in the 
apache configuration a frame for an entire area skipping the database file
completely.

=head1 APACHE

This is a sample configuration for the xpander. If you are strictly 
using the database to do page by page expansion then the C<XpanderAllFiles>,
C<SiteTitle> and the C<Frame> variables are not required, and should 
not be set.

If you are using the rigid expansion from the configuration file then 
the C<XpanderAllFiles> variable must be set to 'On' and the C<Frame> 
variable must be set to a valid frame, the C<SiteTitle> file should
be set but is not required. The C<XpanderDB> need not be set in this case.

  <LocationMatch "^/.+/*\.htm(l?)$">
    SetHandler   perl-script 
    PerlSetVar   XpanderDB          /home/httpd/dangermouse.db 
    PerlSetVar   XpanderAllFiles    On
    PerlSetVar   SiteTitle          "Look ma ! I got a title" 
    PerlSetVar   Frame              Some::Frame
    PerlHandler  KrKit::Xpander
  </LocationMatch>

=head1 DATABASE 

There is no database directly relied upon by this module. It only deals
with the flat database, which is a Berkley DB file. The C<XpanderDB> 
variable specifies where that file is located so that a single site
may have many differenct DB files responsible for different sections
of the site.

The XpanderDB file must be owned by the user the web server is running
as. In general this should either be nobody:nobody or apache:apache
depending on your installation. A simpler method to get the permissons
correct is to chmod the parent directory 777, go to the xpander admin
and once the XpanderDB file is created change the permissons on the
directory back to their previous setting. 

The XpanderDB file need not be in the document root.

=head1 SEE ALSO

L<KrKit(3)>, L<KrKit::Framing(3)>, L<DB_File(3)>

=head1 LIMITATIONS

The expand all variable and the database will conflict if they are 
both set for a single section and the expand all will win, thereby controlling
the look of the output.

=head1 AUTHOR

Nicholas Studt <nicholas@photodwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
