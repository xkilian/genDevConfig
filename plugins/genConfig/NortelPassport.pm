# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2004 Francois Mikus
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

package NortelPassport;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.05;

### End package init


# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

      ### Nortel Passport/ERS
      ### Rapidcity MIB
      'rcSysVersion'                            => '1.3.6.1.4.1.2272.1.1.7.0',
      'rcChasPowerSupplyId'                     => '1.3.6.1.4.1.2272.1.4.8.1.1.1',
      'rcChasPowerSupplyDetailId'               => '1.3.6.1.4.1.2272.1.4.8.2.1.1',
      'rcChasPowerSupplyDetailType'             => '1.3.6.1.4.1.2272.1.4.8.2.1.2',
      'rcChasPowerSupplyDetailSerialNumber'     => '1.3.6.1.4.1.2272.1.4.8.2.1.3',
      'rcChasPowerSupplyDetailHardwareRevision' => '1.3.6.1.4.1.2272.1.4.8.2.1.4',
      'rcChasPowerSupplyDetailPartNumber'       => '1.3.6.1.4.1.2272.1.4.8.2.1.5',
      'rcChasPowerSupplyDetailDescription'       => '1.3.6.1.4.1.2272.1.4.8.2.1.6',
      'rcChasFanId'                             => '1.3.6.1.4.1.2272.1.4.7.1.1.1',
      'rcA1200'                                 => '1.3.6.1.4.1.2272.8',
      'rcA8003'                                 => '1.3.6.1.4.1.2272.280887555',
      'rcA8006'                                 => '1.3.6.1.4.1.2272.280887558',
      'rcA8010'                                 => '1.3.6.1.4.1.2272.280887562',
      'rcA8010co'                               => '1.3.6.1.4.1.2272.1623064842',
      'rcA8610'                                 => '1.3.6.1.4.1.2272.30',
      'rcA8606'                                 => '1.3.6.1.4.1.2272.31',
      'rcA8110'                                 => '1.3.6.1.4.1.2272.32',
      'rcA8106'                                 => '1.3.6.1.4.1.2272.33',
      'rcA8603'                                 => '1.3.6.1.4.1.2272.34',
      'rcA8103'                                 => '1.3.6.1.4.1.2272.35',
      'rcA8110co'                               => '1.3.6.1.4.1.2272.36',
      'rcA8610co'                               => '1.3.6.1.4.1.2272.37',
      'rcA1648'                                 => '1.3.6.1.4.1.2272.43',
      'rcA1612'                                 => '1.3.6.1.4.1.2272.44',
      'rcA1624'                                 => '1.3.6.1.4.1.2272.45',
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'rcA1200'}",
              "$OIDS{'rcA8003'}",
              "$OIDS{'rcA8006'}",
              "$OIDS{'rcA8010'}",
              "$OIDS{'rcA8010co'}",
              "$OIDS{'rcA8610'}",
              "$OIDS{'rcA8606'}",
              "$OIDS{'rcA8110'}",
              "$OIDS{'rcA8106'}",
              "$OIDS{'rcA8603'}",
              "$OIDS{'rcA8103'}",
              "$OIDS{'rcA8110co'}",
              "$OIDS{'rcA8610co'}",
              "$OIDS{'rcA1648'}",
              "$OIDS{'rcA1612'}",
              "$OIDS{'rcA1624'}",
            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $chassispowersupply = 0;
my $chassisfan = 0;
my $script = "Nortel Accelar/Passport/ERS8K/ERS1600 genDevConfig Module";

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
    
    Debug ("Trying to match sysObjectID : " . $opts->{sysObjectID});
    
    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        Debug ("Type : " . $type);
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
    $opts->{class} = 'passport';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('rcSysVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("Model : " . $opts->{model});
    
    if ($opts->{model} =~ /ERS-86/) {
        $opts->{chassisttype} = 'Nortel-ERS8600';
        $opts->{chassisname} = 'chassis.Nortel-ERS8600';
        $chassispowersupply = 1;
        $chassisfan = 1;
    } elsif ($opts->{model} =~ /1200/) {
        $opts->{chassisttype} = 'Nortel-ERS8600';
        $opts->{chassisname} = 'chassis.Nortel-Accelar1200';
        $opts->{class} = 'passport';
        $opts->{chassisinst} = "0";
    } elsif ($opts->{model} =~ /ERS-16/) {
        $opts->{chassisttype} = 'Nortel-ERS1600';
        $opts->{chassisname} = 'chassis.Nortel-ERS1600';
        $opts->{class} = 'passport';
        $opts->{chassisinst} = "0";
    } else {
        $opts->{chassisttype} = 'Nortel-ERS8600';
        $opts->{chassisname} = 'chassis.Nortel-Generic-8K';
        $chassispowersupply = 1;
        $chassisfan = 1;
    }
    
    # Default feature promotions for Nortel routing switches
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
    $opts->{nortelbox} = 1;
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
    
    # Power Supply
    my %idtable;
    my %detailId;
    my %detailType;
    my %detailSerialNumber;
    my %detailHardwareRevision;
    my %detailPartNumber;
    my %detailDescription;
    
    # Fan status
    my %FanId;
   
    if ($chassispowersupply){
       %idtable =              gettable('rcChasPowerSupplyId');
       %detailId =             gettable('rcChasPowerSupplyDetailId');
       %detailType =           gettable('rcChasPowerSupplyDetailType');
       %detailSerialNumber =   gettable('rcChasPowerSupplyDetailSerialNumber');
       %detailHardwareRevision = gettable('rcChasPowerSupplyDetailHardwareRevision');
       %detailPartNumber =     gettable('rcChasPowerSupplyDetailPartNumber');
       %detailDescription =    gettable('rcChasPowerSupplyDetailDescription');
    }
    if ($chassisfan){
       %FanId =                   gettable('rcChasFanId');
    }
   
    ### Build powersupply status
    if ($chassispowersupply) {
         my %typehash = ('1' => "ac",
                         '2' => "dc",
                         '3' => "not installed");
         foreach  my $id (keys %idtable) {
            Debug ("Current id : " . $id);
            next if (!defined($detailId{$id}));
            my $did = $detailId{$id};
            my $type = $detailType{$id};
            my $serial = $detailSerialNumber{$id};
            my $hwversion = $detailHardwareRevision{$id};
            my $partnumber = $detailPartNumber{$id};
            my $description = $detailDescription{$id};

            my ($ldesc, $sdesc);
            $ldesc = "Power Supply Status, power supply " . $id;
            $ldesc .= "<BR>rcChasPowerSupplyId : " . $did . " type : " . $typehash{$type};
            $ldesc .= "<BR>hardware serial and version : " . $serial . " " . $hwversion;
            $ldesc .= "<BR>partnumber : " . $partnumber . " " . $description;
            $sdesc = "Power supply status for ps :" . $id . " type : " . $typehash{$type};
            my ($targetname) = 'powerSupply_' . $id;
         
            $file->writetarget("service {", '',
               'host_name'           => $opts->{devicename},
               'service_description' => "chassis." . $targetname,
               'service_dependencies'=> ",chassis",
               'notes'               => $ldesc,
               'display_name'        => $sdesc,
               '_inst'               => $id,
               '_display_order'              => $opts->{order},
               '_dstemplate'                 => "ERS-Chassis-PS",
               'use'                 => $opts->{dtemplate},
            );
            
            $opts->{order} -= 1;
          }
    }
    
    ### Build Fan status

   
    if ($chassisfan) {
    
        foreach  my $id (keys %FanId) {
            
            my ($ldesc, $sdesc);
            $ldesc = "Fan status for FanId : " . $id;
            $sdesc = "Fan status for FanId : " . $id;
            my ($targetname) = 'fan_' . $id;
            
            $file->writetarget("service {", '',
                'host_name'           => $opts->{devicename},
                'service_description' => "chassis." . $targetname,
                'service_dependencies'=> ",chassis",
                'notes'               => $ldesc,
                'display_name'        => $sdesc,
                '_inst'               => $id,
                '_display_order'              => $opts->{order},
                '_dstemplate'                 => "ERS-Chassis-Fan",
                'use'                 => $opts->{dtemplate},
            );
            
            $opts->{order} -= 1;
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

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###
    
    # Set a non-sticky interface setting for invalid speed in nortel MIBs
    if ($opts->{chassisttype} =~ /^Nortel-ERS/){
        $opts->{nospeedcheck} = 1;
    }
    
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
