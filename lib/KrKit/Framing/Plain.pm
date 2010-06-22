package KrKit::Framing::Plain;

use strict; # Choosey programmers' choose strict.

use KrKit::Framing;

our @ISA = ( 'KrKit::Framing' );

############################################################
# Functions                                                #
############################################################

#-------------------------------------------------
# send( $r, $site )
#-------------------------------------------------
sub send ($$$) {
	my ( $self, $r, $site ) = @_;

	$r->print( 	"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n",
				"<!DOCTYPE html PUBLIC ".
				"\"-//W3C//DTD XHTML 1.0 Transitional//EN\" ".
				"\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">".
				"\n\n",

				"<html>\n<head>\n",
				"<title>$$site{page_title}</title>\n",
				"</head>\n<body>\n\n" );

	$self->SUPER::send( $r, $site ); 	# Use the master send.

	$r->print( "</body>\n</html>\n" );

	return();
} # END send 

# EOF
1;

__END__

=head1 NAME 

KrKit::Framing::Plain - A Plain Framing object.

=head1 SYNOPSIS

  send
    $frame->send( $r, $site );

=head1 DESCRIPTION

This is the plain framing object, it doesn't do a whole lot besides sending
out the content because it is not supposed to. If more options are needed 
use one of the other frames or write your own.

=head1 FUNCTIONS 

=over $frame->send( $r, $site );

  use KrKit::Framing::Plain;

  my $frame = KrKit::Framing::Plain->new(); 
  $frame->send( $r, $site );

This function simply sends the content contained in the 'body_text' value
of C<$site>, or it uses C<< $r->sendfile() >> to send an open file handle
passed in the variable 'body_file'. The frame has almost nothing besides
the open and close body tags.

=back

=head1 SEE ALSO

KrKit::Framing(3), KrKit(3)

=head1 LIMITATIONS

It really dosen't do much, it's plain, if you want more use another or
write your own ;)

=head1 BUGS

None ?

=head1 AUTHOR

Nicholas Studt <nicholas@nicholasstudt.com>

=head1 COPYRIGHT

Copyright (c) 1999-2009 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
