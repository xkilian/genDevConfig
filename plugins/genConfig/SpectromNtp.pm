# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2016 Flavien Peyre
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

package SpectromNtp;

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

      'productVersion' => '1.3.6.1.4.1.18837.3.2.2.1.11.0',
      'rcSpectromNtp' => '1.3.6.1.4.1.18837',
      
      'OidssSysStaPowerAC' => '1.3.6.1.4.1.18837.3.2.2.1.1.0',
      'OidssSysStaPowerDC' => '1.3.6.1.4.1.18837.3.2.2.1.2.0',   
      'OidssSysStaSyncState' => '1.3.6.1.4.1.18837.3.2.2.1.5.0',
      'OidssSysStaHoldoverState' => '1.3.6.1.4.1.18837.3.2.2.1.6.0',
      'OidssSysStaTfom' => '1.3.6.1.4.1.18837.3.2.2.1.7.0',
      'OidssSysStaMinorAlarm' => '1.3.6.1.4.1.18837.3.2.2.1.13.0',
      'OidssSysStaMajorAlarm' => '1.3.6.1.4.1.18837.3.2.2.1.14.0',
    
      'OidssGpsRefTimeValid' => '1.3.6.1.4.1.18837.3.2.2.2.1.1.4',
      'OidssGpsRef1ppsValid' => '1.3.6.1.4.1.18837.3.2.2.2.1.1.5',
      'OidssGpsRefNumSats' => '1.3.6.1.4.1.18837.3.2.2.2.1.1.8',
      'OidssGpsRefAntennaState' => '1.3.6.1.4.1.18837.3.2.2.2.1.1.17',
    
      'OidntpSysStaCurrentMode' => '1.3.6.1.4.1.18837.3.3.2.1.0',
      'OidntpSysStaStratum' => '1.3.6.1.4.1.18837.3.3.2.2.0',
    
      'OidssSysStaEstPhaseError' => '1.3.6.1.4.1.18837.3.2.2.1.8.0',
      'OidssSysStaEstFreqError' => '1.3.6.1.4.1.18837.3.2.2.1.9.0'

    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcSpectromNtp'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "Spectrom Ntp genDevConfig Module";
my $module = "SpectromNtp";

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
    $opts->{class} = 'Spectrom Ntp';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('productVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("$module Model : " . $opts->{model});
    
    $opts->{usev2c} = 1;
    $opts->{dtemplate} = "generic-snmp-template";
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
    my %idtableTime;
    my %idtable1pps;
    my %idtableSats;
    my %idtableAntenna;
    
    my $idAC;
    my $idDC;
    my $idSyncState;
    my $idHoldoverState;
    my $idTfom;
    my $idMinorAlarm;
    my $idMajorAlarm;
    my $idCurrentMode;
    my $idStratum;
    my $idPhaseError;
    my $idFreqError;

    %idtableTime = gettable('OidssGpsRefTimeValid'); 

    foreach my $id (keys %idtableTime) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "gps_valid_time_" . $id,
               'notes'               => "This indicates whether this GPS reference has can provide valid time. (1:valid, 2:invalid)",
               'display_name'        => "GPS valid time " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "spectrom-gps-time",
               '_triggergroup'       => "Spectrom_Gps_Time",
               'use'                 => $opts->{dtemplate},
            );

    }
    
    %idtable1pps = gettable('OidssGpsRef1ppsValid'); 
    foreach my $id (keys %idtable1pps) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "gps_valid_1pps_" . $id,
               'notes'               => "This indicates whether this GPS reference has can provide valid 1PPS.(1:valid, 2:invalid) ",
               'display_name'        => "GPS valid 1pps " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "spectrom-gps-1pps",
               '_triggergroup'       => "Spectrom_Gps_1pps",
               'use'                 => $opts->{dtemplate},
            );

    }    
    
    %idtableSats = gettable('OidssGpsRefNumSats');
    foreach my $id (keys %idtableSats) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "gps_satellites_number_" . $id,
               'notes'               => " This is the number of satellites currently used in position and time fix calculations.",
               'display_name'        => "GPS satellites number " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "spectrom-gps-sats",
               'use'                 => $opts->{dtemplate},
            );

    }
    
    %idtableAntenna = gettable('OidssGpsRefAntennaState');
    foreach my $id (keys %idtableAntenna) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "gps_antenna_state_" . $id,
               'notes'               => "This indicates the current GPS reference antenna state. (1:ok, 2:short, 3:open, 4:unknown)",
               'display_name'        => "GPS antenna state " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "spectrom-gps-antenna",
               '_triggergroup'       => "Spectrom_Gps_Antenna",
               'use'                 => $opts->{dtemplate},
            );

    }    
    
    ($idAC) = get("OidssSysStaPowerAC");
    next if (!defined ($idAC));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "power_ac",
            'notes'               => "General status of the AC power input.(1:ok,2:alarm,3:none)",
	    'display_name'        => "Power AC ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-system-powerAC",
	    '_triggergroup'       => "Spectrom_Power_AC",
	    'use'                 => $opts->{dtemplate},
	);

    ($idDC) = get("OidssSysStaPowerDC");
    next if (!defined ($idDC));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "power_dc",
            'notes'               => "General status of the DC power input.(1:ok,2:alarm,3:none)",
	    'display_name'        => "Power DC ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-system-powerDC",
	   '_triggergroup'        => "Spectrom_Power_DC",
	    'use'                 => $opts->{dtemplate},
	);

    ($idSyncState) = get("OidssSysStaSyncState");
    next if (!defined ($idSyncState));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "synchronization_state",
            'notes'               => "Status of the unit's syncronization with its time/1pps references. (1:sync,2:nosync)",
	    'display_name'        => "Synchronization state ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-system-sync",
	    '_triggergroup'       => "Spectrom_System_Sync",
	    'use'                 => $opts->{dtemplate},
	);

    ($idHoldoverState) = get("OidssSysStaHoldoverState");
    next if (!defined ($idHoldoverState));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "holdover_state",
            'notes'               => "When in holdover, the unit has lost its references, is fly-wheeling
	    using the oscillator, and the time and frequency outputs are still
	    within specifications.",
	    'display_name'        => "Holdover state ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-system-holdover",
	    'use'                 => $opts->{dtemplate},
	);

    ($idTfom) = get("OidssSysStaTfom");
    next if (!defined ($idTfom));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "tfom",
            'notes'               => "with respect to the selected time/1pps references.  The following
	    table identifies the ranges per TFOM value:
	    0:TFOM is not defined, ETE is unknown
	    1:ETE <=1 nsec
	    2:1 nsec < ETE <=10 nsec
	    3:10 nsec < ETE <=100 nsec
	    4:100 nsec < ETE <=1 usec
	    5:1 usec < ETE <=10 usec
	    6:10 usec < ETE <=100 usec
	    7:100 usec < ETE <=1 msec
	    8:1 msec < ETE <=10 msec
	    9:10 msec < ETE <=100 msec
	    10:100 msec < ETE <=1 sec
	    11:1 sec  < ETE <=10 sec
	    12:10 sec  < ETE <=100 sec
	    13:100 sec  < ETE <=1000 sec
	    14:1000 sec  < ETE <=10000 sec
	    15:ETE >  10000 sec",
	    'display_name'        => "Tfom ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-system-tfom",
	    '_triggergroup'       => "Spectrom_System_Tfom",
	    'use'                 => $opts->{dtemplate},
	);

    ($idMinorAlarm) = get("OidssSysStaMinorAlarm");
    next if (!defined ($idMinorAlarm));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "minor_alarm",
            'notes'               => " This indicates whether or not a minor alarm is currently active.
	    The value of pending indicates that the alarm condition is active and
	    is pending resolution. (1:pending, 2:clear)",
	    'display_name'        => "Minor Alarm ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-state-minor",
	    '_triggergroup'       => "Spectrom_Alarm_Minor",
	    'use'                 => $opts->{dtemplate},
	);

    ($idMajorAlarm) = get("OidssSysStaMajorAlarm");
    next if (!defined ($idMajorAlarm));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "major_alarm",
            'notes'               => "This indicates whether or not a major alarm is currently pending.
	    The value of pending indicates that the alarm condition is active and
	    is pending resolution.(1:pending, 2:clear)",
	    'display_name'        => "Major alarm ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-state-major",
	    '_triggergroup'       => "Spectrom_Alarm_Major",
	    'use'                 => $opts->{dtemplate},
	);

    ($idCurrentMode) = get("OidntpSysStaCurrentMode");
    next if (!defined ($idCurrentMode));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "ntp_current_mode",
            'notes'               => "Current Status of the NTP application. (1:unknown,2:notRuniing,3:notSynchronized,4:synchronized)",
	    'display_name'        => "NTP current mode ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-ntp-mode",
	    '_triggergroup'       => "Spectrom_State_Mode",
	    'use'                 => $opts->{dtemplate},
	);

    ($idStratum) = get("OidntpSysStaStratum");
    next if (!defined ($idStratum));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "ntp_stratum",
            'notes'               => "Current stratum of the NTP application.",
	    'display_name'        => "NTP stratum ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-ntp-stratum",
	    'use'                 => $opts->{dtemplate},
	);

    ($idPhaseError) = get("OidssSysStaEstPhaseError");
    next if (!defined ($idPhaseError));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "phase_error",
            'notes'               => "This indicates the estimated phase error (magnitude) of the unit's
            internal 1PPS with respect to the selected 1pps reference.",
	    'display_name'        => "Phase error ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-ntp-phase",
	    'use'                 => $opts->{dtemplate},
	);

    ($idFreqError) = get("OidssSysStaEstFreqError");
    next if (!defined ($idFreqError));
    $file->writetarget("service {", '',
	    'host_name'           => $opts->{devicename},
	    'service_description' => "frequence_error" ,
            'notes'               => "This indicates the estimated frequency error (magnitude) of the unit's
            internal 10 MHz oscillator with respect to the selected 1pps
            reference.",
	    'display_name'        => "Frequence error ",
	    '_inst'               => "0",
	    '_dstemplate'         => "spectrom-ntp-freq",
	    'use'                 => $opts->{dtemplate},
	);


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
