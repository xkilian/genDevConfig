# -*-perl-*-
#    genDevConfig plugin module for Catalyst switches running CatOS
#
#    Copyright (C) 2003 Mike Fisher
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package Cisco1548m;

use strict;
use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 0.02;

### End package init

# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.

my @types = ('Cisco 1548M Micro Switch',
            );

# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.

my %OIDS = (
	    ### from MIB2
	    udpInDatagrams  => '1.3.6.1.2.1.7.1',
	    udpOutDatagrams => '1.3.6.1.2.1.7.4',

	    snmpInPkts      => '1.3.6.1.2.1.11.1',
	    snmpOutPkts     => '1.3.6.1.2.1.11.2',
           );

### Misc private stuff...

my %snmpinpkts;

###############################################################################
# device_types
# IN : N/A
# OUT: returns an array ref of devices this plugin can handle
###############################################################################

sub device_types {
   return \@types;
}

###############################################################################
###############################################################################

sub can_handle {
    my($self, $opts) = @_;

    return (grep { $opts->{sysDescr} =~ m/$_/gi } @types)

}

###############################################################################
# discover
# IN : ref to options hash
# OUT: n/a
###############################################################################

sub discover {
    my($self, $opts) = @_;

    $opts->{'model'} = 'Cisco 1548M Micro Switch';

    ### Add our OIDs to the global list

    register_oids(%OIDS);

    ### Check that everything works ok...

    %snmpinpkts = gettable('snmpInPkts');

    return;
}

###############################################################################
# custom_targets
# IN : ref to options hash
# OUT: n/a
###############################################################################

sub custom_targets {
    my($self, $data, $opts) = @_;

    
    foreach my $key (keys(%snmpinpkts)) {
	Info("snmpInPkts key: $key\n"); 
    }

    my $desc = 'SNMP packets';
    my $targetname = 'snmp_stats';
    
    $opts->{'file'}->writetarget($targetname, '',
				 'order'         => $opts->{order},
				 'inst'          => (keys %snmpinpkts)[0],
				 'display-name'  => $targetname,
				 'short-desc'    => $desc,
				 'long-desc'     => $desc,
				 'target-type'   => 'snmpstats');
    
    $opts->{order} -= 1;

    return;
}

###############################################################################

sub custom_interfaces {

}

###############################################################################

sub custom_files {

}

###############################################################################

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
