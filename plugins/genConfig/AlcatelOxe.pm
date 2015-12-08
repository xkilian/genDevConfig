# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2015 Flavien Peyre
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

package AlcatelOxe;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.00;

### End package init

# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

    'productVersion' => '1.3.6.1.4.1.637.64.4400.1.0.0',
    'rcAlcatelOxe' => '1.3.6.1.4.1.637.64.4400.1.1.10',


    'OidpbxState' => '1.3.6.1.4.1.637.64.4400.1.2',
    'OidconfAvailable' => '1.3.6.1.4.1.637.64.4400.1.3.1.2',
    'OidconfBusy' => '1.3.6.1.4.1.637.64.4400.1.3.1.3',
    'OidconfOutOfOrder' => '1.3.6.1.4.1.637.64.4400.1.3.1.4',
    'OiddspRessAvailable' => '1.3.6.1.4.1.637.64.4400.1.3.1.5',
    'OiddspRessBusy' => '1.3.6.1.4.1.637.64.4400.1.3.1.6',
    'OiddspRessOutOfService' => '1.3.6.1.4.1.637.64.4400.1.3.1.7',
    'OiddspRessOverrun' => '1.3.6.1.4.1.637.64.4400.1.3.1.8',
    'OidcacAllowed' => '1.3.6.1.4.1.637.64.4400.1.3.1.9',
    'OidcacUsed' => '1.3.6.1.4.1.637.64.4400.1.3.1.10',
    'OidcacOverrun' => '1.3.6.1.4.1.637.64.4400.1.3.1.11',

     'hrSystemNumUsers'         => '1.3.6.1.2.1.25.1.5',    # .0
     'hrSystemProcesses'        => '1.3.6.1.2.1.25.1.6',    # .0


    # Load averages.
     'ucd_loadTable'        => '1.3.6.1.4.1.2021.10.1.3',
     'ucd_load1min'         => '1.3.6.1.4.1.2021.10.1.3.1',
     'ucd_load5min'         => '1.3.6.1.4.1.2021.10.1.3.2',
    'ucd_load15min'        => '1.3.6.1.4.1.2021.10.1.3.3',
	    
    # Memory stats
     'ucd_memswapAvail'     => '1.3.6.1.4.1.2021.4.4.0',
     'ucd_memrealAvail'     => '1.3.6.1.4.1.2021.4.6.0',
     'ucd_memtotalAvail'    => '1.3.6.1.4.1.2021.4.11.0',
	    
    # Disk stats (Don't forget the instance number...)
     'ucd_diskpath'	   => '1.3.6.1.4.1.2021.9.1.2',
     'ucd_diskfree'        => '1.3.6.1.4.1.2021.9.1.7',
     'ucd_diskused'         => '1.3.6.1.4.1.2021.9.1.8',
     'ucd_diskpused'        => '1.3.6.1.4.1.2021.9.1.9',
	    
    # CPU Stats
     'ucd_cpuUser'          => '1.3.6.1.4.1.2021.11.9.0',
     'ucd_cpuSystem'        => '1.3.6.1.4.1.2021.11.10.0',
     'ucd_cpuIdle'          => '1.3.6.1.4.1.2021.11.11.0',
     'ucd_rawCpuUser'       => '1.3.6.1.4.1.2021.11.50.0',
     'ucd_rawCpuNice'       => '1.3.6.1.4.1.2021.11.51.0',
     'ucd_rawCpuSystem'     => '1.3.6.1.4.1.2021.11.52.0',
     'ucd_rawCpuIdle'       => '1.3.6.1.4.1.2021.11.53.0',
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcAlcatelOxe'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "Alcatel Oxe genDevConfig Module";
my $module = "AlcatelOxe";

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
    $opts->{class} = 'AlcatelOxe';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('productVersion');
    $opts->{vendor_descr_oid} = "ifName";
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
    my $idtablePS; 
    my $idtableGenericInfo;   
    my %idtableCoA;
    my %idtableCoB;
    my %idtableCoOOO;
    my %idtableDRA;
    my %idtableDRB;
    my %idtableDROOS;
    my %idtableDRO;
    my %idtableCaA;
    my %idtableCaU;
    my %idtableCaO;
    my %idtableDisk;

    ($idtableGenericInfo) = get("ucd_cpuUser");
    if (defined ($idtableGenericInfo)){
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "generic_netSNMP" ,
#               'notes'               => $ldesc,
               'display_name'        => "Generic box netsnmp",
               '_inst'               => 0,
               '_dstemplate'                 => "generic-box-netsnmp",
               'use'                 => $opts->{dtemplate},
            );    
    }

    ($idtablePS) = get("OidpbxState");
    if (defined ($idtablePS)){
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "pbx_status" ,
#               'notes'               => $ldesc,
               'display_name'        => "Pbx status",
               '_inst'               => 0,
               '_dstemplate'                 => "alcatel-pbx-state",
               '_triggergroup'               => "Alcatel_Pbx",
               'use'                 => $opts->{dtemplate},
            );    
    }

    %idtableDisk = gettable('ucd_diskfree');
    foreach my $id (keys %idtableDisk) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => get("ucd_diskpath.$id"),
#               'notes'               => $ldesc,
               'display_name'        => "Disk information from netsnmp",
               '_inst'               => $id,
               '_dstemplate'         => "ucd_Storage",               
               'use'                 => $opts->{dtemplate},
            );
     }

    %idtableCoA = gettable('OidconfAvailable');
    foreach my $id (keys %idtableCoA) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "conference_circuit",
#               'notes'               => $ldesc,
               'display_name'        => "Conference circuits available, busy and out of order",
               '_inst'               => $id,
               '_dstemplate'         => "alcatel-conf",               
               'use'                 => $opts->{dtemplate},
            );
     }
     
    %idtableDRA = gettable('OiddspRessAvailable');
    foreach my $id (keys %idtableDRA) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "dsp_ress",
#               'notes'               => $ldesc,
               'display_name'        => "Compressors available, busy, out of service and overrun",
               '_inst'               => $id,
               '_dstemplate'         => "alcatel-dspRess",               
               'use'                 => $opts->{dtemplate},
            );
    }     
    %idtableCaA = gettable('OidcacAllowed');
    foreach my $id (keys %idtableCaA) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "cac",
#               'notes'               => $ldesc,
               'display_name'        => "External communications allowed, used and overrun",
               '_inst'               => $id,
               '_dstemplate'         => "alcatel-cac",               
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
