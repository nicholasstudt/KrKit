package KrKit;

use strict;

our $VERSION = '1.0';

############################################################
# Functions                                                #
############################################################

# EOF
1;

__END__

=head1 NAME 

KrKit - For when the average fails. 

=head1 SYNOPSIS

  use KrKit; # <-- This doesn't import anything or do anything.

=head1 DESCRIPTION

This module contains the top level information about what modules this
library contains. There is nothing of perl in this module. 

=head1 MODULES

=over 4

=item KrKit::AppBase

AppBase contains utility functions that may be helpful. These include
dealing with cookies and sending mail.

=item KrKit::Calendar

These module creates a couple calendar views that can be used by other
applications and are highly customizeable. 

=item KrKit::Control

This module is a library of useful access functions that would be used
in other handlers, it also details the other modules that belong to the
Control tree.

=item KrKit::DB

These functions wrap the common DBI calls to Databases with error
checking. 

=item KrKit::Framing

This is the core of the framing system in use by the KrKit libraries. 
The other Framing objects inherit most of these functions.

=item KrKit::Handler

This module contains the OO handler.  Exactly how the OO handler works
is described within.

=item KrKit::HTML

Implements HTML tags in a browser non-specfic way conforming to 
3.2 and above HTML specifications.

=item KrKit::Helper

This module is the head of the help system. It is also the viewer for
the help system.

=item KrKit::SQL 

This module supplies easy ways to make strings sql safe as well as 
allowing the creation of sql commands. All of these commands should 
work with any database as they do not do anything database specfic, 
well as far as I know anyways.

=item KrKit::Validate

This module allows the validation of many common types of input.

=item KrKit::Xpander

This module, handler, relies on a database file to expand files into a frame
if the frame is defined. There is also the ability to specify in the 
apache configuration a frame for an entire area skipping the database file
completely.

=back

=head1 SEE ALSO

L<perl(3)>, L<httpd(3)>, L<mod_perl(3)>

=head1 LIMITATIONS

Limitations are listed in the modules they apply to.

=head1 AUTHOR

Nicholas Studt <nicholas@photodwarf.org> and Ron Andrews <ron@cognilogic.net>

=head1 COPYRIGHT

Copyright (c) 1999-2010 by Nicholas Studt. All rights reserved.

You may distribute under the terms of either the GNU General Public
License or the Artistic License, as specified in the Perl README file.

=cut
