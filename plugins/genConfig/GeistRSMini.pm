# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2015 Sebastien Coavoux
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

# To test this configuration use GenDev with the following params:
#./genDevConfig --snmpv2c --community geist-avec-capteur-eau2 --nodns  127.0.0.1 --loglevel INFO
#

package GeistRSMini;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.03;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

    'productVersion'            => '1.3.6.1.4.1.21239.2.1.2.0',
    'rcRsMini'                  => '1.3.6.1.4.1.21239.2',

    'OidtempSensorTempC'        => '1.3.6.1.4.1.21239.2.4.1.5',
    'OidclimateHumidity'        => '1.3.6.1.4.1.21239.2.2.1.7', #Not sure what this does or why this was here.
    'OidclimateAirflow'         => '1.3.6.1.4.1.21239.2.2.1.9',

    'OidairFlowSensorTempC'     => '1.3.6.1.4.1.21239.2.5.1.5',
    'OidairFlowSensorFlow'      => '1.3.6.1.4.1.21239.2.5.1.7',
    'OidairFlowSensorHumidity'  => '1.3.6.1.4.1.21239.2.5.1.8',
    'OidairFlowSensorDewPointC' => '1.3.6.1.4.1.21239.2.5.1.9',

    'climateIO1'                => '1.3.6.1.4.1.21239.2.2.1.11',
    'climateIO2'                => '1.3.6.1.4.1.21239.2.2.1.12',
    'climateIO3'                => '1.3.6.1.4.1.21239.2.2.1.13'
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcRsMini'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "Geist RS Mini genDevConfig Module";
my $module = "GeistRSMini";

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
    
    # Default options for all Geist RSMINI devices
    $opts->{class} = 'Geist RSMINI';
    $opts->{chassisinst} = "0";
    ($opts->{vendor_soft_ver}) = get('productVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("$module Model : " . $opts->{model});
    
    $opts->{usev2c} = 1;
    $opts->{dtemplate} = "generic-co-env-mdg-service";
    $opts->{htemplates} = "SnmpBooster-host-MDG";
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
    my %idtableST;
    my $idtableSH;
    my $idtableSF;
    my $idtableSD;
    my $idtableSC;

    %idtableST = gettable('OidtempSensorTempC'); 

    foreach my $id (keys %idtableST) {
    $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "temperature_sensor_" . $id,
               'notes'               => "(Degrees Celsius) Temperature sensor when in alarm, check for progression and raise an issue.",
               'display_name'        => "Temperature sensor " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "geist-sensor-temperature",
               '_triggergroup'       => "RSMini_Temp_Complex",
               '_timeout'            => "15",
               'use'                 => $opts->{dtemplate},
            );
    }

    foreach my $id (0..15) {
    	($idtableSH) = get("OidairFlowSensorHumidity.$id");
 	next if (!defined ($idtableSH));
    	$file->writetarget("service {", '',
               	'host_name'           => $opts->{devicename},
               	'service_description' => "airflow_humidity_" . $id,
               'notes'               => "(Percentage)",
               'display_name'         => "Airflow humidity " . $id,
               '_inst'                => $id,
               '_dstemplate'          => "geist-airflow-humidity",
               '_timeout'            => "15",
              # '_triggergroup'       => "RSMini_Temp",
               'use'                  => $opts->{dtemplate},
            );
    }
    foreach my $id (0..15) {
    	($idtableSF) = get("OidairFlowSensorFlow.$id");
	next if (!defined ($idtableSF));    
	$file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "airflow_airflow_" . $id,
              #'notes'               => $ldesc,
               'display_name'        => "Airflow airflow " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "geist-airflow-airflow",
               '_timeout'            => "15",
              #'_triggergroup'       => "RSMini_Temp",
               'use'                 => $opts->{dtemplate},
            );
    }
    foreach my $id (0..15) {
    	($idtableSD) = get("OidairFlowSensorDewPointC.$id");
 	 next if (!defined ($idtableSD));
    	 $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "airflow_dewpoint_" . $id,
               'notes'               => "(Degrees Celsius) Airflow sensor.",
               'display_name'        => "Airflow Dew Point " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "geist-airflow-dewpoint",
               '_timeout'            => "15",
              #'_triggergroup'       => "RSMini_Temp",
               'use'                 => $opts->{dtemplate},
            );
    }
    foreach my $id (0..15) {
    	($idtableSC) = get("OidairFlowSensorTempC.$id");
 	 next if (!defined ($idtableSC));
    	 $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "airflow_temperature_" . $id,
               'notes'               => "Flow sensor when in alarm, check for progression and raise an issue.",
               'display_name'        => "Airflow Temperature " . $id,
               '_inst'               => $id,
               '_dstemplate'         => "geist-airflow-temperature",
               '_timeout'            => "15",
              #'_triggergroup'       => "RSMini_Temp",
               'use'                 => $opts->{dtemplate},
            );
    }

    foreach my $id (11..13){
        my $state;
        if($id == 11) {
            my %map = gettable('climateIO1');
            $state = $map{1};
        }
        if($id == 12) {
            my %map = gettable('climateIO2');
            $state = $map{1};
        }
        if($id == 13) {
            my %map = gettable('climateIO3');
            $state = $map{1};
        }
        if($state != 99){
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "External analog humidity sensor (climateIO" . ($id % 10) . ")",
                'notes'               => "Externally attached analog humidity sensor",
                'display_name'        => "Humidity status " . $id,
                '_inst'               => $id,
                '_dstemplate'         => "geist-analog-external-humidity",
                '_timeout'            => "15",
                #'_triggergroup'       => "RSMini_Temp",
                'use'                 => $opts->{dtemplate},
            );
        }
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
