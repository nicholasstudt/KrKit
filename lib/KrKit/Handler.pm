package KrKit::Handler;

use strict;

use Apache2::Const -compile => qw(:common);
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::ServerUtil;

use KrKit::AppBase;
use KrKit::DB;

#-------------------------------------------------
# $site->_cleanroot( $uri, $root )
#-------------------------------------------------
sub _cleanroot {
	my ( $site, $uri, $root ) = @_;

	$uri =~ s!^$root!!g;
	$uri =~ s/\/\//\//g;
	$uri =~ s/^\///;

	return( split( '/', $uri ) );
} # END $site->_cleanroot

#-------------------------------------------------
# $site->_cleanup( $r )
#-------------------------------------------------
sub _cleanup {
	my ( $site, $r ) = @_;

 	db_disconnect( $$site{dbh} );

	return();
} # END $site->_cleanup

#-------------------------------------------------
# $site->_decline()
#-------------------------------------------------
sub _decline {
	my ( $site ) = @_;

	$$site{_decline_} = 1; # Tag it for the handler to handle nice.

	return( Apache2::Const::DECLINED );
} # END $site->_decline

#-------------------------------------------------
# $site->_init( $r );
#-------------------------------------------------
sub _init {
	my ( $site, $r ) = @_; 

	# Page specfic variables
	$$site{'uri'}           = $r->uri;
	$$site{'rootp'}         = $r->location;
	$$site{'contenttype'}   = 'text/html';
	$$site{'onpage_title'}  = ''; 
	$$site{'frame'}			= $r->dir_config( 'Frame' );
	$$site{'page_title'}	= ( $r->dir_config( 'SiteTitle' ) 	|| '' );

	# Not always used or set.
	$$site{'help'}			= $r->dir_config( 'HelpRoot' ) 		|| '';
	$$site{'smtp_host'}		= $r->dir_config( 'SMTP_Host' ) 	|| '';

	# File Upload Variables.
	$$site{'file_tmp'}		= $r->dir_config( 'File_Temp' ) 	|| '/tmp';
	$$site{'file_path'}		= $r->dir_config( 'File_Path' ) 	|| '/tmp';
	$$site{'file_uri'}		= $r->dir_config( 'File_URI' ) 		|| '/tmp';
	$$site{'file_max'}		= $r->dir_config( 'File_PostMax' )  || '3145728';
		# 3MB post max limit.

	# Date/Time formats.
	$$site{'fmt_d'}			= $r->dir_config( 'Date_Format' ) 		|| '%x';
	$$site{'fmt_t'}			= $r->dir_config( 'Time_Format' ) 		|| '%X';
	$$site{'fmt_dt'}		= $r->dir_config( 'DateTime_Format' ) 	|| '%x %X';

	# Must happen last. 
	$$site{'dbtype'} 	= $r->dir_config( 'DatabaseType' );
	my $dbns			= $r->dir_config( 'DatabaseNameSpace' );
	$$site{'dbns'}		= db_getnamespace( $$site{dbtype}, $dbns );
	$$site{'dbh'}		= db_connect( appbase_get_dbparam( $r ) );

	return();
} # END $site->_init

#-------------------------------------------------
# $site->_relocate( $r, $location )
#-------------------------------------------------
sub _relocate {
	my ( $site, $r, $location ) = @_;
	
	die( 'Invalid apache request object.' ) if ( ! defined $r );

	$location = $r->location if ( ! defined $location );

	$$site{_redirect_} = 1; # Tag it for the handler to handle nice.

	$r->headers_out->set( 'Location' => $location );

	$r->status( Apache2::Const::REDIRECT ); 

	return( Apache2::Const::REDIRECT );
} # END $site->_relocate 

#-------------------------------------------------
# $self->handler( $r );
#-------------------------------------------------
sub handler : method {
	my ( $class, $r ) = @_;

	my $self 	= {};
	my @txt;

	bless( $self, ref( $class ) || $class );	# Yes, they are meek.

	eval { 								
		my @p 		= $self->_cleanroot( $r->uri, $r->location );
		my $action 	= 'do_'. ( shift( @p ) || 'main' );

		if ( $self->can( $action ) ) { 	

			$self->_init( $r ); 		# Init
			$self->_init_app( $r ) if ( $self->can( '_init_app' ) );

			push( @txt, $self->$action( $r, @p ) );
		
			$self->_cleanup( $r );		# Cleanup.
			$self->_cleanup_app( $r ) if ( $self->can( '_cleanup_app' ) );
		}
		else {
			$$self{_decline_} = 1;
		}

		$$self{_decline_} = 1 if ( $txt[0] eq Apache2::Const::DECLINED );
	};

	return( Apache2::Const::REDIRECT ) if ( $$self{_redirect_} ); 	# 302
	return( Apache2::Const::DECLINED ) if ( $$self{_decline_} );	# 404

	push( @txt, '<b>Error:</b><br /><i>', $@, '</i>' ) if ( $@ );

	eval {
		my $frame = appbase_get_frame( $r, $$self{frame} );

		$r->content_type( $$self{contenttype} );
		$r->no_cache( 1 ) 	if ( $r->dir_config( 'NoCache' ) );

		$$self{body_text} = join( "\n", @txt, "\n" );

		$frame->send( $r, $self );
	};

	$r->print( "Framing Error: $@" ) if ( $@ );

	return( Apache2::Const::OK );
} # END $self->handler

#-------------------------------------------------
# $self->opt( $var, $val )
#-------------------------------------------------
sub opt {
	my ( $self, $var, $val ) = @_;
	
	if ( defined $val ) {
		return( $self->{$var} = $val );
	}
	else {
		return( $self->{$var} );
	}
} # END $self->opt

#-------------------------------------------------
# $self->param( $apr )
#-------------------------------------------------
sub param {
	my ( $self, $apr ) = @_;

	my %in; 

	if ( $apr->param ) { 		# Make sure we have something.

		#%in = %{$apr->param}; # Does not deal with multivalue.

		for my $name ( $apr->param ) {
			
			if ( exists $in{$name} )  {
				my @vals 	= $apr->param( $name );
				$in{$name} 	= \@vals;
			}
			else {
				$in{$name} = $apr->param( $name );
			}
		}
	}

	return( \%in ); # A hash reference
} # END $self->param

# EOF
1;

__END__

=head1 NAME 

KrKit::Handler - A inheritable handler.

=head1 SYNOPSIS

  use KrKit::Handler;

  @ISA = ( 'KrKit::Handler' );

=head1 DESCRIPTION

This module contains the OO handler.  Exactly how the OO handler works
is described within.

=head1 METHODS

=over 4

=item $site->_cleanup( $r )

This method disconnects from the database.

=item $site->_init( $r )

This method sets up the C<$site> object for use by the other methods.
It sets the following values in C<$site>. 'uri', 'rootp', 'contenttype',
'onpage_title', 'dbh', 'page_title', and 'frame'. 'contenttype' defaults
to "text/html" and should be changed in another method if it is
different. 'dbh' is the connect to the database generated by
appbase_get_dbparam(). 'page_title' is set from "SiteTitle" and 'frame'
is set from "Frame" in the apache config.  This also sets the 'help'
value in site which is pulled from the PerlSetvar 'HelpRoot'. This is
need for the help subsystem. 

FIXME: Note all of the variables in a list.

=over 4

=item File_Tmp, etc

=back

=item $site->_init_app( $r )

=item $site->_relocate( $r, $location )

=item $self->handler( $r )

This is the default handler that can be inherited it calls _init, and
_cleanup. Methods to be called from this handler should be of the naming
convention do_name. If this cannot be found then the autoloader is
called to return declined. Methods should take $r, and any other
parameters that are in the uri past the method name. 

=back

=head1 SEE ALSO

KrKit(3)

=head1 LIMITATIONS

The main function has to be do_main where this is inherited. 

=head1 AUTHOR

Nicholas Studt <nstudt@angrydwarf.org>

=head1 COPYRIGHT

Copyright (c) 1999-2005 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
