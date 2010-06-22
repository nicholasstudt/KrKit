package KrKit::Framing::Template;

use strict; # Choosey programmers' choose strict.
#use Apache2::RequestIO;
use POSIX qw( strftime );

use KrKit::Framing;

our @ISA = ( 'KrKit::Framing' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# $frame->get_template( $r )
#-------------------------------------------------
sub get_template ($$) {
	my ( $self, $r ) = @_;

	my $template = $self->option( 'template' );

	# Check for valid characters. ( don't know if this is right )
	if ( $template !~ /^~?[a-z0-9\/\_\-\+\.]+$/i ) { 
		die "Invalid template name '$template'.";
	}

	# Make sure we don't have .. in the template
	if ( $template =~ /\.\./ ) {
		die "Invalid template name '$template'.";
	}

	my $dir = '';

	if ( $template =~ s/^~// ) { 	# In the docroot
		$dir = $r->document_root();
	}
	else { 							# Maybe Not in the docroot
		$dir = $r->dir_config( 'TemplateDir' );
	}

	my $file = "$dir/$template";

	open( TEMPLATE, "<$file" ) or die "Could not open '$file': $!";

	return( \*TEMPLATE );
} # END $frame->get_template

#-------------------------------------------------
# $frame->send( $r, $site )
#-------------------------------------------------
sub send ($$$) {
	my ( $self, $r, $site ) = @_;

	my $template_fh = $self->get_template( $r );
	my @datetime 	= localtime();

	# Walk the file handle
	while ( my $line = <$template_fh> ) {

		# if line dosen't start with ## print and go to the next line.
		if ( $line !~ /^##/ ) {
			$r->print( $line );
			next;
		}

		# BODY_TEXT
		if ( $line =~ /^##BODY_TEXT##/o ) {
			if ( defined $$site{body_file} ) {
				# FIXME: Should I really have to flush this here ?
				# If it isn't the sendfile comes fore $r->print content.
				$r->rflush();
				$r->sendfile( $$site{body_file} );
			}
			else {
				$r->print( $$site{body_text} );
			}
			next;
		}

		# BODY_AUX 
		if ( $line =~ /^##BODY_AUX##/o ) {
			$$site{body_aux} = '' if ( ! defined $$site{body_aux} );
			$r->print( $$site{body_aux} );
			next;
		}

		# PAGE_TITLE
		if ( $line =~ /^##PAGE_TITLE##/o ) {
			$$site{page_title} = '' if ( ! defined $$site{page_title} );
			$r->print( $$site{page_title} );
			next;
		}

		# ONPAGE_TITLE
		if ( $line =~ /^##ONPAGE_TITLE##/o ) {
			$$site{onpage_title} = '' if ( ! defined $$site{onpage_title} );
			$r->print( $$site{onpage_title} );
			next;
		}

		# DATE
		if ( $line =~ /^##DATE##/o ) {
			$r->print( strftime( $$site{fmt_d}, @datetime ) );
			next;
		}

		# TIME
		if ( $line =~ /^##TIME##/o ) {
			$r->print( strftime( $$site{fmt_t}, @datetime ) );
			next;
		}

		# DATE_TIME
		if ( $line =~ /^##DATE_TIME##/o ) {
			$r->print( strftime( $$site{fmt_dt}, @datetime ) );
			next;
		}

		# STRFTIME
		if ( $line =~ /^##STRFTIME=/o ) {
			
			my ( $format ) = $line =~ /^##STRFTIME=(.*)##/;

			$r->print( strftime( $format, @datetime ) );
			next;
		}

		# USER_NAME
		if ( $line =~ /^##USER_NAME##/o ) {
			$r->print( $r->user || 'anonymous' );
			next;
		}

		# INDEX
		if ( $line =~ /^##INDEX##/o ) {
			$r->print( $self->index( $r, $site ) );
			next;
		}

		# INCLUDE=
		if ( $line =~ /^##INCLUDE=/o ) {

			my @p 			= split( '/', $r->uri );
			my ( $file ) 	= $line =~ /^##INCLUDE=(.*)##/;
			my $root 		= $r->document_root();
			my $path		= join( '/', @p ) || '';
	
			if ( $file !~ m/^~?[a-z0-9\/\_\-\+\.]+$/i ) { 
				$r->print( "Error: Invalid template filename '$file'." );
				next;
			}

			# Ignore those hackers, trim any ".." out.
			if ( $file =~ /\.\./ ) {
				$r->print( "Error: Invalid template filename '$file'." );
				next;
			}
			
			$file =~ s/^~//;
			
			$r->rflush();

			if ( $file !~ /\// ) {

				if ( scalar( @p ) > 1 ) {
 					while ( ! -e "$root/$path/$file" ) {
						return( "Error: No $file" ) if ( scalar( @p ) < 1 );
						pop( @p );
						$path = join( '/', @p ) || '';
					}
				}

				if ( -e "$root/$path/$file" ) {
					$r->sendfile( "$root/$path/$file" );
				}
				else {
					$r->print( "Error: Could not include '$file'." );
				}
			}
			else {
				if ( -e "$root/$file" ) {
					$r->sendfile( "$root/$file" );
				}
				else {
					$r->print( "Error: Could not include '$file'." );
				}
			}

			next;
		}

		# IF we haven't done anything yet, just print.
		$r->print( $line );
	}

	# close the file handle.
	close( $template_fh );

	return;
} # END $frame->send 

# EOF
1;

__END__

=head1 NAME 

KrKit::Framing::Template - Template based framing.

=head1 SYNOPSIS

  get_template
    $template_fh = $frame->get_template( $r );

  send
    $frame->send( $r, $site );

=head1 DESCRIPTION

This Module allows static template files to be used to wrap content.
These files can be located under the document root or another template
directory defined through the apache config. The available keys are 
detailed in the Function C<< $frame->send() >>.

=head1 APACHE

To utilize this module it must be B<use'd> in the Perl section. Simply
use the construction "template;<templatefile>". A couple examples
follow. The first example contains the template in the docroot, the
second contains it in directory defined by C<TemplateDir>.

  TemplateDir /home/httpd/template
  Framing template;~/template.tp
  Framing template;templatefile.tp

=head1 TEMPLATE KEYS

=over 4

=item ##BODY_TEXT##

This is the actual content from the page or the application.

=item ##PAGE_TITLE##

This is the contents of the title set in the Xpander or from
applications. 

=item ##ONPAGE_TITLE##

This is the title that is usually only set by applications.

=item ##DATE##

FIXME:
This is the current date set according to "%A, %B %e, %Y" in strtftime
syntax. 

=item ##DATE_TIME##

FIXME:
This is the current date and time set according to 
"%A, %B %e, %Y %I:%M %p %Z" in strtftime syntax.

=item ##TIME##

FIXME:
This is the current time set according to "%I:%M %p %Z" in strtftime
syntax. 

=item ##STRFTIME=%A %B %stftime_syntax##

This allows the use of strftime directly from the template system,
everything between = and ## are passed to strftime as a format. The
formats can be found in "man strftime" on a unix like system.

=item ##USER_NAME##

This is the user that is currently authenticated through apache. If no
user is currently set it will return the username 'anonymous'. 

=item ##INDEX##

This tag allows the display of .index file navigation. The first line of
the .index file should be the title then a '|' and then either 'sorted'
if the following entries should be alpha-numerically sorted or not. The
sorted need not be specfied.

The rest of the file should be name and relative uri to the directory
the .index file is in seperated by '|'. 

'#' can be used to denote comments.

=item ##INCLUDE=~/<file>##

This tag allows the ability to include files into the template. The 
files must be inside of the current document root. Any includes that 
have C<../> in their url will produce an error. Any includes that do
not start with C<~/> will also produce an error. The file to include
is sent with a C<< $r->sendfile >> therefore no parsing is done on the 
file at all.

=back

=head1 SEE ALSO

KrKit(3), KrKit::Framing(3), KrKit::Xpander(3)

=head1 LIMITATIONS

The commands to interperate must be on a line by themeselves or they 
will not be used at all. 

=head1 BUGS

None ?

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
