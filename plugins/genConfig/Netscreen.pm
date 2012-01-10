# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2003 Francois Mikus
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

package Netscreen;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.06;

### End package init

# These are the OIDs used by this plugin
# the OIDs should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.

my %OIDS = ('nsIdsAttkMonSynAttk' => '1.3.6.1.4.1.3224.3.2.1.3'
           );

###############################################################################
# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.
###############################################################################

my @types = ( 'Net[sS]creen-\d+',
            );

###############################################################################
#### Private variables
################################################################################

my $snmp;
my $req_fwstats = 1; # Default is always provide these stats.
my $fwstats;
my $script = "Netscreen genDevConfig module";

###############################################################################
# plugin_name
# IN : N/A
# OUT: returns the name of the plugin
###############################################################################

sub plugin_name {
   my $self = shift;
   return $script;
}

###############################################################################
# device_types
# IN : N/A
# OUT: returns an array ref of devices this plugin can handle
###############################################################################

sub device_types {
   my $self = shift;
   return \@types;
}

#-------------------------------------------------------------------------------
# can_handle
# IN : opts reference
# OUT: returns a true if the device can be handled by this plugin
#-------------------------------------------------------------------------------

sub can_handle {
    my($self, $opts) = @_;


    foreach my $type (@types) {
        return ($opts->{sysDescr} =~ m/$type/gi)
        #$type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        #return ($opts->{sysObjectID} =~ m/$type/gi)
    }
    return 0;

}

#-------------------------------------------------------------------------------
# discover
# IN : options hash
# OUT: returns the model and options hash
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    $opts->{model} = 'Netscreen';
    $opts->{class} = 'netscreen';

    if ($opts->{model} eq "Netscreen") {
        $opts->{chassisttype} = 'Netscreen-Firewall';
        $opts->{chassisname} = 'Chassis-Netscreen';
    }

    # Default feature promotions
    $fwstats = 1		if ($req_fwstats);
    $opts->{extended} = 0	if ($opts->{req_extended});

    ###
    ### END DEVICE DISCOVERY SECTION
    ###

    return;
}

#-------------------------------------------------------------------------------
# custom_targets
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_targets {
    my ($self, $data, $opts) = @_;

    my $file = $opts->{file};

    ###
    ### DEVICE CUSTOM CONFIG SECTION
    ###

    if ($fwstats) {

        my ($ldesc, $sdesc);
        $ldesc = "Number of active and failed sessions for the entire firewall";
        $sdesc = "Number of active and failed sessions for the entire firewall";
        my ($targetname) = 'netscreen_sessions_statistics';

        $file->writetarget($targetname, '',
            'inst'           => '0',
            'order'          => $opts->{order},
            'interface-name' => $targetname,
            'long-desc'      => $ldesc,
            'short-desc'     => $sdesc,
            'target-type'    => 'Netscreen-sessions',
        );
        $opts->{order} -= 1;

        my %nsIdsAttkMonSynAttk = gettable('nsIdsAttkMonSynAttk');
        my $count = scalar(keys %nsIdsAttkMonSynAttk);
        for (my $ifindex = 0; $ifindex < $count; $ifindex++) {

            $ldesc = "Current number of attacks for ifindex $ifindex ";
            $sdesc = "Current number of attacks for ifindex $ifindex";
            $targetname = "netscreen_attack_statistics_if_$ifindex";

            $file->writetarget($targetname, '',
                'inst'             => $ifindex,
                'order'            => $opts->{order},
                'interface-name'   => $targetname,
                'long-desc'        => $ldesc,
                'short-desc'       => $sdesc,
                'target-type'      => 'Netscreen-attacks',
            );

            $opts->{order} -= 1;
        }
    }



    return;
}


#-------------------------------------------------------------------------------
# custom_interfaces
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_interfaces {
    my ($self, $index, $data, $opts) = @_;

    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my @config     = @{$data->{config}};
    my $hc         = $data->{hc};
    my $class      = $data->{class};
    my $peerid     = $data->{peerid};
    my $match      = $data->{match};
    my $sdesc      = $data->{sdesc};
    my $ldesc      = $data->{ldesc};
    
    ###
    ### DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    push(@config, 'target-type' => 'standard-interface' . $hc);
    $match = 1;

    ###
    ### END INTERFACE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}}  = %ifspeed;
    %{$data->{ifdescr}}  = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}}   = %iftype;
    %{$data->{ifmtu}}    = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;
    @{$data->{config}} = @config;
    $data->{hc}     = $hc;
    $data->{class}  = $class;
    $data->{peerid} = $peerid;
    $data->{match}  = $match;
    $data->{sdesc}  = $sdesc;
    $data->{ldesc}  = $ldesc;

    return;
}
1;
