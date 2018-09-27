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

package EMCDataDomain;

#use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.03;
my $debug = 0;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (
    'sysDescription'      => '1.3.6.1.2.1.1.1',
    'sysObjectId'         => '1.3.6.1.2.1.1.2',
    'EMCDataDomain'       => '1.3.6.1.4.1.19746.3.1.36',
    'powerSupplyArrayIdx' => '1.3.6.1.4.1.19746.1.1.1.1.1.1.1',
    'powerSupplyArray'    => '1.3.6.1.4.1.19746.1.1.1.1.1.1',
    'tempSensorArrayIdx'  => '1.3.6.1.4.1.19746.1.1.2.1.1.1.1',
    'tempSensorArray'     => '1.3.6.1.4.1.19746.1.1.2.1.1.1',
    'fanArrayIdx'         => '1.3.6.1.4.1.19746.1.1.3.1.1.1.1',
    'fanArray'            => '1.3.6.1.4.1.19746.1.1.3.1.1.1',
    'diskArrayIdx'        => '1.3.6.1.4.1.19746.1.6.1.1.1.1',
    'diskArray'           => '1.3.6.1.4.1.19746.1.6.1.1.1',
    'fsArrayIdx'          => '1.3.6.1.4.1.19746.1.3.2.1.1.1',
    'fsArray'             => '1.3.6.1.4.1.19746.1.3.2.1.1'
    );


###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'EMCDataDomain'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $script = "EMCDataDomain genDevConfig Module";
my $module = "EMCDataDomain";

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
    
    # Default options for EMC DataDomain
    # TODO: Find out which ones these are....
    $opts->{class} = 'EMCDataDomain';
    $opts->{chassisinst} = "0";
    ($opts->{vendor_soft_ver}) = get('productVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("$module Model : " . $opts->{model});
    
    $opts->{usev2c} = 1;
    #TODO: dtemplate should probably also be different.
    $opts->{dtemplate} = "generic-co-env-mdg-service";
    $opts->{htemplates} = "SnmpBooster-host-MDG";
    return;
}

sub discoverIndexes {
    my %table = @_;
    my %map;
    foreach my $key (keys %table){
        my @keyset = split /\./ , $key;
        my $head = @keyset[0];
        my $tail = @keyset[1];
        push(@{$map{$head}}, $tail);
    }
    return %map;
}

sub discoverSingleIndexes{
    my %table = @_;
    my @map;
    foreach my $key (keys %table){
        push(@map, $key);
    }
    return @map;
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
    ### Includes PSU, FAN, TEMP
    ###

    my %index;

    #This PSU
    %index = discoverIndexes(gettable('powerSupplyArrayIdx'));
    my %psus =  gettable('powerSupplyArray');

    if(isDebug) {
        foreach my $idx (keys %index) {
            Debug("Equipement group is " . $idx);
            foreach (@{$index{$idx}}) {
                Debug("Name = " . $psus{'3.' . $idx . "." . $_} . " | Status = " . $psus{'4.' . $idx . "." . $_});
            }
        }
    }

    #Now we try to build a service entry for each of the PSUs
    my $ldesc = "(Status: 0=absent,1=OK,2=failed,3=fault,4=acnone,99=unknown) ";
    foreach my $idx (keys %index){
        Debug("Writing configuration for device group ".$idx);
        foreach (@{$index{$idx}}){
            my $auxdesc = "Power supply group ".$idx." | Name: ".$psus{'3.'.$idx.".".$_};
            my $displayName = "Group ".$idx."-Supply ".$_;
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "Power supply group ".$idx,
                'notes'               => $ldesc." ".$auxdesc,
                'display_name'        => $displayName,
                '_inst'               => $idx.".".$_,
                '_dstemplate'         => "EMCDataDomain-Generic",
                '_timeout'            => "15",
                #'_triggergroup'       => "RSMini_Temp",
                'use'                 => $opts->{dtemplate},
            );
        }
    }

    %index = ();


    #This is for temperature.
    %index = discoverIndexes(gettable('tempSensorArrayIdx'));
    my %temps =  gettable('tempSensorArray');

    if(isDebug) {
        foreach my $idx (keys %index) {
            Debug("Equipement group is " . $idx);
            foreach (@{$index{$idx}}) {
                Debug("Name = " . $temps{'4.' . $idx . "." . $_} . "| Value = " . $temps{'5.' . $idx . "." . $_} . "| State = " . $temps{'6.' . $idx . "." . $_});
            }
        }
    }

    #File writing
    my $ldesc = "(Status: 1=ok,2=notfound,3=overheatwarn,4=overheatcritical) ";
    foreach my $idx (keys %index){
        Debug("Writing configuration for device group ".$idx);
        foreach (@{$index{$idx}}){
            my $auxdesc = "Temp. Sensor Group ".$idx." | Device location: ".$temps{'4.'.$idx.".".$_};
            my $displayName = "Group ".$idx."-Temperature Monitor ".$_;
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "Temperature group ".$idx,
                'notes'               => $ldesc." ".$auxdesc,
                'display_name'        => $displayName,
                '_inst'               => $idx.".".$_,
                '_dstemplate'         => "EMCDataDomain-Generic",
                '_timeout'            => "15",
                #'_triggergroup'       => "RSMini_Temp",
                'use'                 => $opts->{dtemplate},
            );
        }
    }
    %index = ();


    #This is for fans.
    %index = discoverIndexes(gettable('fanArrayIdx'));
    my %fans = gettable('fanArray');

    if(isDebug) {
        foreach my $idx (keys %index) {
            Debug("Equipement group is " . $idx);
            foreach (@{$index{$idx}}) {
                Debug("Name = " . $fans{'4.' . $idx . "." . $_} . "| Level = " . $fans{'5.' . $idx . "." . $_} . "| State = " . $fans{'6.' . $idx . "." . $_});
            }
        }
    }

    #File writing
    $ldesc = "(Level: 0=unknown,1=low,2=medium,3=high;  Status:0=ok,1=fail,2=fail) ";
    foreach my $idx (keys %index){
        Debug("Writing configuration for device group ".$idx);
        foreach (@{$index{$idx}}){
            my $auxdesc = "Fan group ".$idx." | Name: ".$fans{'4.'.$idx.".".$_};
            my $displayName = "Group ".$idx."-Fan ".$_;
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "Fan group ".$idx,
                'notes'               => $ldesc." ".$auxdesc,
                'display_name'        => $displayName,
                '_inst'               => $idx.".".$_,
                '_dstemplate'         => "EMCDataDomain-Generic",
                '_timeout'            => "15",
                #'_triggergroup'       => "RSMini_Temp",
                'use'                 => $opts->{dtemplate},
            );
        }
    }

    %index = ();


    #This is for disks (just trying for now)
    %index = discoverIndexes(gettable('diskArrayIdx'));
    my %disks = gettable('diskArray');

    if(isDebug) {
        foreach my $idx (keys %index) {
            Debug("Equipement group is " . $idx);
            foreach (@{$index{$idx}}) {
                Debug("Name = " . $disks{'4.' . $idx . "." . $_} . "| Firmware = " . $disks{'5.' . $idx . "." . $_} . " | Serial = " . $disks{'6.' . $idx . "." . $_} .
                    " | Capacity = " . $disks{'7.' . $idx . "." . $_} . " | State = " . $disks{'8.' . $idx . "." . $_});
            }
        }
    }

    #File writing
    $ldesc = "(Status: 1=ok,2=unknown,3=absent,4=failed,5=spare,6=available) ";
    foreach my $idx (keys %index){
        Debug("Writing configuration for device group ".$idx);
        foreach (@{$index{$idx}}){
            my $auxdesc = "Disk group ".$idx. " | Disk Information: " .$disks{'4.'.$idx.".".$_}."/".$disks{'6.'.$idx.".".$_};
            my $displayName = "Group ".$idx."-Disk ".$_;
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "Disk group ".$idx,
                'notes'               => $ldesc." ".$auxdesc,
                'display_name'        => $displayName,
                '_inst'               => $idx.".".$_,
                '_dstemplate'         => "EMCDataDomain-Generic",
                '_timeout'            => "15",
                #'_triggergroup'       => "RSMini_Temp",
                'use'                 => $opts->{dtemplate},
            );
        }
    }

    %index = ();


    #This is for filesystem data
    my @index = discoverSingleIndexes(gettable('fsArrayIdx'));
    my %fs = gettable('fsArray');

    if(isDebug) {
        foreach (@index) {
            Debug("File system ID " . $_);
            Debug("Name :" . $fs{'3.' . $_} . " | Percent space used: " . $fs{'7.' . $_});
        }
    }

    #File writing
    $ldesc = "Filesystem usage in %";
    foreach(@index){
        Debug("Writing configuration for device group ".$_);
        my $auxdesc = "Mount point ".$fs{'3.'.$_};
        $file->writetarget("service {", '',
            'host_name'           => $opts->{devicename},
            'service_description' => "Filesystem ".$_,
            'notes'               => $ldesc,
            'display_name'        => $auxdesc,
            '_inst'               => $_,
            '_dstemplate'         => "EMCDataDomain-Generic",
            '_timeout'            => "15",
            #'_triggergroup'       => "RSMini_Temp",
            'use'                 => $opts->{dtemplate},
        );
    }


    %index = ();



    #%arr =  gettable('temperatureArray');
    #foreach(@instances){
    #        Debug("Unit " . $arr{'3.' . $_ . '.'.$subid} . "| Status = ".$arr{'4.' . $_ . '.'.$subid});
    #}




    #{
    #    $file->writetarget("service {", '',
    #        'host_name'           => $opts->{devicename},
    #        'service_description' => "EMCDataDomain power supply set " . $_,
    #        'notes'               => "Power supply with id",
    #       'display_name'        => "Temperature sensor " . $_,
    #       '_inst'               => $_,
    #       '_dstemplate'         => "geist-sensor-temperature",
    #       '_triggergroup'       => "RSMini_Temp_Complex",
    #       '_timeout'            => "15",
    #       'use'                 => $opts->{dtemplate},
    #    );
    #}


    #%idtableST = gettable('OidtempSensorTempC');
    #foreach my $id (keys %idtableST) {
    #$file->writetarget("service {", '',
    #           'host_name'           => $opts->{devicename},
    #           'service_description' => "temperature_sensor_" . $id,
    #           'notes'               => "(Degrees Celsius) Temperature sensor when in alarm, check for progression and raise an issue.",
    #           'display_name'        => "Temperature sensor " . $id,
    #           '_inst'               => $id,
    #           '_dstemplate'         => "geist-sensor-temperature",
    #           '_triggergroup'       => "RSMini_Temp_Complex",
    #           '_timeout'            => "15",
    #           'use'                 => $opts->{dtemplate},
    #        );
    #}

    #Here we have an override for the case when we have the new WatchDog 15.



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
