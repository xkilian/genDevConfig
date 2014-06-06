# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2014 Francois Mikus
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

package OSA;

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

      ### Nortel Passport/ERS
      ### Rapidcity MIB
      'OSA5220'                            => '1.3.6.1.4.1.2021.250.10',
      'osaSysVersion'                      => '1.3.6.1.4.1.5551.1.0.11',
      'osaOntpsnmp'                        => '1.3.6.1.4.1.5551.1.0',
      'osaGpssnmp'                     => '1.3.6.1.4.1.5551.1.0',
    );

###############################################################################
## These are device types we can handle in this plugin
## the names should be contained in the sysdescr string
## returned by the devices. The name is a regular expression.
################################################################################
my @types = ( "$OIDS{'OSA5220'}",

            );


###############################################################################
### Private variables
###############################################################################

my $snmp;
my $ntpstat = 0;
my $gpsstat = 0;
my $script = "Oscilloquartz 5220 GPS receiver and NTP source";

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
    
    #Cannot get coherent data using the perl snmp library, always returns 1
    #my $model = get('osaSysVersion');
    #Debug ("Model: " . $model);
    $opts->{model} = "OSA-Unknown" ;
      
    # Default options for all oscilloquartz class devices
    $opts->{class} = 'oscilloquartz';
    $opts->{chassisinst} = "0";
    $opts->{vendor_soft_ver} = get('osaSysVersion');
    $opts->{vendor_descr_oid} = "ifName";
    $opts->{sysDescr} .= "<BR>" . $opts->{vendor_soft_ver} . "<BR>" . $opts->{sysLocation};
 
    Debug("Model : " . $opts->{model});
    
    if ($opts->{model} =~ /OSA 5220/) {
        $opts->{chassisttype} = 'OSA-5220';
        $opts->{chassisname} = 'chassis.OSA-5220';
        $opts->{chassistriggergroup} = 'chassis_OSA-5220';
    }  else {
        $opts->{chassisttype} = 'OSA-Generic';
        $opts->{chassisname} = 'chassis.generic';
        #$opts->{chassistriggergroup} = 'chassis_OSA-5220';
        $opts->{class} = 'oscilloquartz';

    }
    
    # Default feature promotions for Nortel routing switches
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});
    $opts->{oscilloquartzbox} = 1;
    $opts->{dtemplate} = "default-snmp-template-bulk";
    $ntpstat = 1;
    $gpsstat =1;
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
    
    my $id = 0;

   
    ### Build NTP subsystem stats
    if ($ntpstat) {

      my ($ldesc, $sdesc);
      $sdesc = "NTP subsystem Time Figure of Merit 4 to 9, a higher number being bad sync to GPS.";
      $ldesc = "NTP subsystem Time Figure of Merit 4 to 9, a higher number being bad sync to GPS, consult Oscilloquartz manual.";
   
      $file->writetarget("service {", '',
         'host_name'           => $opts->{devicename},
         'service_description' => "ntpstat.TFOM",
         'notes'               => $ldesc,
         'display_name'        => $sdesc,
         '_inst'               => $id,
         '_display_order'              => $opts->{order},
         '_dstemplate'                 => "OSA-Chassis-TFOM",
         '_triggergroup'               => "ontpstat_TFOM",
         'use'                 => $opts->{dtemplate},
      );
      
      $opts->{order} -= 1;
      

      $sdesc = "NTP subsystem Authentication failures.";
      $ldesc = "NTP subsystem Authentication failures.";
   
      $file->writetarget("service {", '',
         'host_name'           => $opts->{devicename},
         'service_description' => "ntpstat.authfailures",
         'notes'               => $ldesc,
         'display_name'        => $sdesc,
         '_inst'               => $id,
         '_display_order'              => $opts->{order},
         '_dstemplate'                 => "OSA-ntp-authfailure",
         '_triggergroup'               => "ontpstat_authfailure",
         'use'                 => $opts->{dtemplate},
      );
      
      $opts->{order} -= 1;
      
      $sdesc = "NTP subsystem OffsetToSyncSource, is the NTP subsystem drifting.";
      $ldesc = "NTP subsystem OffsetToSyncSource, is the NTP subsystem drifting.";
   
      $file->writetarget("service {", '',
         'host_name'           => $opts->{devicename},
         'service_description' => "ntpstat.offsetToSyncSource",
         'notes'               => $ldesc,
         'display_name'        => $sdesc,
         '_inst'               => $id,
         '_display_order'              => $opts->{order},
         '_dstemplate'                 => "OSA-ntp-offset",
         #'_triggergroup'               => "ontpstat_offset",
         'use'                 => $opts->{dtemplate},
      );
      
      $opts->{order} -= 1;
          
          
    }
    
    ### Build gps subsystem stats

   
    if ($gpsstat) {
    
       
      my ($ldesc, $sdesc);       
      $sdesc = "GPS subsystem State and Statistics.";
      $ldesc = "GPS subsystem State and Statistics.";
   
      $file->writetarget("service {", '',
         'host_name'           => $opts->{devicename},
         'service_description' => "gpsstat.all",
         'notes'               => $ldesc,
         'display_name'        => $sdesc,
         '_inst'               => 0,
         '_display_order'              => $opts->{order},
         '_dstemplate'                 => "OSA-gps-stats",
         '_triggergroup'               => "ogpsstat_all",
         'use'                 => $opts->{dtemplate},
      );
      
      $sdesc = "GPS subsystem Time Figure of Merit 4 to 6, a higher number being bad sync to satelittes, consult Oscilloquartz manual.";
      $ldesc = "GPS subsystem Time Figure of Merit 4 to 6, a higher number being bad sync to satelittes, consult Oscilloquartz manual.";    
      $file->writetarget("service {", '',
         'host_name'           => $opts->{devicename},
         'service_description' => "gpsstat.TFOM",
         'notes'               => $ldesc,
         'display_name'        => $sdesc,
         '_inst'               => $id,
         '_display_order'              => $opts->{order},
         '_dstemplate'                 => "OSA-gps-TFOM",
         '_triggergroup'               => "ogpsstat_TFOM",
         'use'                 => $opts->{dtemplate},
      );
      
      $opts->{order} -= 1;
          
       
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
    my $c          = $data->{c};
    my $target = $data->{target};

    ###
    ### START DEVICE CUSTOM INTERFACE CONFIG SECTION
    ###
    
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
    $data->{target} = $target;
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
