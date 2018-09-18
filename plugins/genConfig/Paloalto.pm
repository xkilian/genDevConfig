# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2017 Flavien Peyre
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

package Paloalto;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.02;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

      'productVersion'                  => '1.3.6.1.2.1.47.1.1.1.1.2.1',
      'rcPaloAlto2020'                      => '1.3.6.1.4.1.25461.2.3.4',
      'rcPaloAlto500'                      => '1.3.6.1.4.1.25461.2.3.6',
      'rcPaloAltoPanorama'                      => '1.3.6.1.4.1.25461.2.3.7',
      'rcPaloAlto3020'                      => '1.3.6.1.4.1.25461.2.3.18',
      'rcPaloAlto3050'                      => '1.3.6.1.4.1.25461.2.3.17',

      'OidhrSystemUptime'               => '1.3.6.1.2.1.25.1.1.0',
      'OidhrProcessorLoad1'             => '1.3.6.1.2.1.25.3.3.1.2.1',
      'OidpanSessionUtilization'        => '1.3.6.1.4.1.25461.2.1.2.3.1.0',
      'OidpanGPGWUtilizationPct'        => '1.3.6.1.4.1.25461.2.1.2.5.1.1',
      'OidpanVsysSessionUtilizationPct' => '1.3.6.1.4.1.25461.2.1.2.3.9.1.3',



    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcPaloAlto2020'}",
              "$OIDS{'rcPaloAlto500'}",
              "$OIDS{'rcPaloAltoPanorama'}",
              "$OIDS{'rcPaloAlto3020'}",
              "$OIDS{'rcPaloAlto3050'}"
            );



###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "Paloalto genDevConfig Module";
my $module = "Paloalto";

###############################################################################
###############################################################################

#-------------------------------------------------------------------------------
# plugin_name
# IN : N/A
# OUT: returns the name of the plugin
#-------------------------------------------------------------------------------

sub plugin_name {
   my $self = shift;
   return $script;
}

#-------------------------------------------------------------------------------
# device_types
# IN : N/A
# OUT: returns an array ref of devices this plugin can handle
#-------------------------------------------------------------------------------

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

    Debug ("$module Trying to match sysObjectID : " . $opts->{sysObjectID});

    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        Debug ("$module Type : " . $type);
        return 1 if ($opts->{sysObjectID} =~ m/$type/gi)
    }
    return 0;
}

#-------------------------------------------------------------------------------
# discover
# IN : options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out the OS version number this device is running.
    ### We need this to figure out which oid to use to get
    ### interface descriptions and which
    ### MIBs are supported.

    $opts->{model} = $opts->{sysDescr};

    # Default options for all passport class devices
    $opts->{class} = 'PaloAlto';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('productVersion');
    $opts->{vendor_descr_oid} = "ifNamePaloAlto";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};

    Debug("$module Model : " . $opts->{model});

    $opts->{usev2c} = 1;
    $opts->{dtemplate} = "default-snmp-template";
    return;
}

#-------------------------------------------------------------------------------
# custom_targets
# IN : data reference for transient data, options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_targets {
    my ($self,$data,$opts) = @_;

    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my $file = $opts->{file};

    ###
    ### START DEVICE CUSTOM CONFIG SECTION
    ###
    my %idtableVsys;
    my $idtableChassis;
    my $idtableSession;
    my %idtableGPGW;
    my $idtableUptime;

    %idtableVsys = gettable('OidpanVsysSessionUtilizationPct');

    foreach my $id (keys %idtableVsys) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "paloalto_vsys_session_" . $id,
               'display_name'        => "Paloalto Vsys " . $id . " session utilization",
               'notes'               => "Vsys Session utilization(%), number of maximum sessions, number of active session. Warning if Session utilization > 85%, Critical for > 95%",
               '_inst'               => $id,
               '_dstemplate'         => "Paloalto-Chassis-Sessions-Vsys",
               '_triggergroup'       => "Paloalto_Session_Vsys_Utilization",
               'use'                 => $opts->{dtemplate},
            );

    }

    ($idtableChassis) = get("OidhrProcessorLoad1");
    if (defined ($idtableChassis)){
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "paloalto_proc",
               'display_name'        => "Paloalto processus load",
               'notes'               => "CPU util on management plane, Utilization of CPUs on dataplane that are used for system functions. No trigger",
               '_dstemplate'         => "Paloalto-Chassis",
               'use'                 => $opts->{dtemplate},
            );
    }

    ($idtableSession) = get("OidpanSessionUtilization");
    if (defined ($idtableSession)){
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "paloalto_session" ,
               'display_name'        => "Paloalto session utilization",
               'notes'               => "Session utilization(%), maximum of sessions, number of current session (Total, TCP,UDP and ICMP). Warning if Session utilization > 85%, Critical for > 95%",
               '_dstemplate'         => "Paloalto-Chassis-Sessions",
               '_triggergroup'       => "Paloalto_Session_Utilization",
               'use'                 => $opts->{dtemplate},
            );
    }

    %idtableGPGW = gettable('OidpanGPGWUtilizationPct');

    foreach my $id (keys %idtableGPGW) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "paloalto_gateway" ,
               'display_name'        => "Paloalto gateway utilization",
               'notes'               => "Global Protect Gateway (GPGW) utilization(%), number of maximum tunnels, number of active tunnels. Warning if tunnel utilization > 85%, Critical for > 95%",
               '_dstemplate'         => "Paloalto-Chassis-GPGW",
               '_triggergroup'       => "Paloalto_Session_GPGW_Utilization",
               '_inst'               => $id,
               'use'                 => $opts->{dtemplate},
            );
    }

    ($idtableUptime) = get("OidhrSystemUptime");
    if (defined ($idtableUptime)){
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "paloalto_uptime" ,
               'display_name'        => "Paloalto Uptime",
               'notes'               => "Uptime of the device",
               '_dstemplate'         => "Paloalto-Chassis-Uptime",
               'use'                 => $opts->{dtemplate},
            );
    }


    ###
    ### END DEVICE CUSTOM CONFIG SECTION
    ###

    # Saving local copies of runtime data
    %{$data->{ifspeed}} = %ifspeed;
    %{$data->{ifdescr}} = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}} = %iftype;
    %{$data->{ifmtu}} = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;

    return;
}

#-------------------------------------------------------------------------------
# custom_interfaces
# IN : current ifIndex,
#      data reference for transient data
#      options reference
# OUT: N/A
#-------------------------------------------------------------------------------

sub custom_interfaces {
    my ($self,$index,$data,$opts) = @_;

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
    my $match      = $data->{match};
    my $customsdesc = $data->{customsdesc};
    my $customldesc = $data->{customldesc};
    my $c = $data->{c};


    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###

    # Set a non-sticky interface setting for invalid speed in nortel MIBs

    ###Debug ("$module Interface name: $ifdescr{$index}, $intdescr{$index}");
    push(@config, '_dstemplate' => 'standard-interface-noql');
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
    $data->{match}  = $match;
    $data->{customsdesc} = $customsdesc;
    $data->{customldesc} = $customldesc;
    $data->{c} = $c;
    return;
}

#-------------------------------------------------------------------------------
# custom_files
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub custom_files {
    my ($self,$data,$opts) = @_;

    # Saving local copies of runtime data
    my $file           = $data->{file};
    my $c              = $data->{c};
    my $target         = $data->{target};
    my @config         = @{$data->{config}};
    my $wmatch         = $data->{wmatch};

    ###
    ### START FILE CUSTOM CONFIG SECTION
    ###

    ###
    ### END FILE CUSTOM CONFIG SECTION
    ###

    # Save return value in the reference hash
    $data->{wmatch}  = $wmatch;
}

1;

