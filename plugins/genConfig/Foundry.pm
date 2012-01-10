# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2002 Francois Mikus
#    Copyright (C) 2005 CHIRP Project chirp.sourceforge.net.
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

package Foundry;

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


###############################################################################
# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.
###############################################################################
my @types = ( '1.3.6.1.4.1.1991', # Foundry Generic
            );

###############################################################################
# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
###############################################################################
my %OIDS = (
       ### from FOUNDRY-SN-ROOT-MIB
       ### foundry.products.switch.snSwitch.snSwPortInfo...

       'snSwPortName'                => '1.3.6.1.4.1.1991.1.1.3.3.1.1.24',
       'snSwPortIfIndex'             => '1.3.6.1.4.1.1991.1.1.3.3.1.1.38',
       'snSwPortDescr'               => '1.3.6.1.4.1.1991.1.1.3.3.1.1.39',

       ### from FOUNDRY-SN-ROOT-MIB
       ### foundry.products.switch.snAgentSys.snAgentGbl...

       'snAgBuildVer'				=> '1.3.6.1.4.1.1991.1.1.2.1.49',

       'snL4VirtualServerTable'			=> '1.3.6.1.4.1.1991.1.1.4.2.1.1',
       'snL4RealServerTable'			=> '1.3.6.1.4.1.1991.1.1.4.3.1.1',

       'snL4VirtualServerPortTable'		=> '1.3.6.1.4.1.1991.1.1.4.4.1.1',
       'snL4RealServerPortTable'		=> '1.3.6.1.4.1.1991.1.1.4.5.1.1',

      );

###############################################################################
### Private variables
###############################################################################

my %types = ( '1.3.6.1.4.1.1991.1.3.3.1' =>  'ServerIron',
	      '1.3.6.1.4.1.1991.1.3.3.2' =>  'ServerIron XL',
	      '1.3.6.1.4.1.1991.1.3.3.2' =>  'ServerIron XLTCS',
              '1.3.6.1.4.1.1991.1.3.18.1' => 'ServerIron 400',
	      '1.3.6.1.4.1.1991.1.3.19.1' =>  'ServerIron 800',
	      '1.3.6.1.4.1.1991.1.3.20.1' =>  'ServerIron 1500',
	      '1.3.6.1.4.1.1991.1.3.5.4' =>  'ServerIronXLG',
	      '1.3.6.1.4.1.1991.1.3.5.1' =>  'TurboIron8',
	      '1.3.6.1.4.1.1991.1.3.6.2' =>  'BigIron 4000',
	      '1.3.6.1.4.1.1991.1.3.7.2' =>  'BigIron 8000',
            );

my $script = "Foundry genDevConfig module";

#-------------------------------------------------------------------------------
# plugin_name
# IN : N/A
# OUT: returns the name of the plugin.
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

    foreach my $type (@types) {
        $type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        return ($opts->{sysObjectID} =~ m/$type/gi)
        # Example using string instead of a OID match
        #return ($opts->{sysDescr} =~ m/$type/gi)
    }
    return 0;
}

#-------------------------------------------------------------------------------
# discover
# IN : options hash
# OUT: returns the options hash
#-------------------------------------------------------------------------------

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    ### Figure out which oid to use to get interface descriptions and which
    ### MIBs are supported.
    ###

    # Default feature promotions for Foundry Devices
    $opts->{foundrybox} = 1	if ($opts->{req_vendorbox});
    $opts->{namedonly} = 1	if ($opts->{req_namedonly});
    $opts->{usev2c} = 1		if ($opts->{req_usev2c});
    $opts->{model} = 'Foundry-Generic';
    $opts->{chassisttype} = 'Chassis-Foundry-Generic';
    $opts->{chassisname} = 'Chassis-Foundry';
    $opts->{vendor_soft_ver}  = get('snAgBuildVer');
    $opts->{model} = 'Foundry-Generic';
    
    if ($types{$opts->{sysObjectID}} =~ /^BigIron/) {
        $opts->{model} = 'Foundry-BigIron';
        $opts->{vendor_soft_ver}  = ''; # get('snAgBuildVer'); Find out what MIB for BigIron
        # Model specific feature promotions for Foundry Devices

    } elsif ($types{$opts->{sysObjectID}} =~ /^TurboIron/) {
        $opts->{model} = 'Foundry-ServerIron';
        # Model specific feature promotions for Foundry Devices

    } elsif ($types{$opts->{sysObjectID}} =~ /^ServerIron/) {
        $opts->{model} = 'Foundry-ServerIron';
        # Model specific feature promotions for Foundry Devices
    }

    $opts->{vendor_descr_oid} = 'ifAlias';
    # $opts->{vendor_descr_oid} = 'snSwPortName';

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

    if ($opts->{model} =~ /ServerIron/) {
        my $targetname = 'slb_summary';
        $file->writetarget($targetname, '',
                        'interface-name' => $targetname,
                        'long-desc'      => "Total L4SLB conn statistics for $opts->{devicename}",
                        'short-desc'     => "Total L4SLB conn stats for $opts->{devicename}",
                        'target-type'    => 'foundryL4SLB',
                        'order'          => $opts->{order},
                    );
        $opts->{order} -= 1;
    }

    my %snL4RealServerTable = gettable('snL4RealServerTable');
    my %snL4VirtualServerTable = gettable('snL4VirtualServerTable');
    my %snL4VirtualServerPortTable = gettable('snL4VirtualServerPortTable');
    my %snL4RealServerPortTable = gettable('snL4RealServerPortTable');

    my %virtuals;
    my %reals;
    my $result;
    if ($opts->{model} =~ /ServerIron/) {
    $result = rehash (%snL4RealServerTable);

    foreach my $row (sort keys %{$result}) {
    	my ($servername, $serverip, $adminstate) = ($result->{$row}->{2}, $result->{$row}->{3}, $result->{$row}->{4});
    	next unless (defined $adminstate && $adminstate == 1);
        my $targetname = 'slb_' . $serverip;
    	$file->writetarget($targetname, '',
                        'interface-name' => $servername,
                        'long-desc'      => "Real Server $servername ($serverip)",
                        'short-desc'     => "Real Server $servername",
                        'target-type'    => 'foundry-real-server',
                        'order'          => $opts->{order},
                    );
        $opts->{order} -= 1;
        $reals{$servername} = $serverip;
    }

    $result = rehash (%snL4VirtualServerTable);
  
  
  foreach my $row (sort keys %{$result}) {
    my ($servername, $serverip, $adminstate) = ($result->{$row}->{2}, $result->{$row}->{3}, $result->{$row}->{4});
    next unless (defined $adminstate && $adminstate == 1);
        my $targetname = 'slb_' . $serverip;
    	$file->writetarget($targetname, '',
                        'interface-name' => $servername,
                        'long-desc'      => "Virtual Server $servername ($serverip)",
                        'short-desc'     => "Virtual Server $servername",
                        'target-type'    => 'foundry-virtual-server',
                        'order'          => $opts->{order},
                    );
        $opts->{order} -= 1;
    $virtuals{$servername} = $serverip;
  }
  
  $result = rehash (%snL4RealServerPortTable);
  
  foreach my $row (sort keys %{$result}) {
    my ($servername, $serverport, $adminstate) = ($result->{$row}->{2}, $result->{$row}->{3}, $result->{$row}->{4});
    my ($serverport1) = ($serverport == "65535")?"default":$serverport;
    next unless (defined $adminstate && $adminstate == 1);
    my $serverip = $reals{$servername};
    my $targetname = 'slb_' . $serverip . '.' . $serverport1;
    $file->writetarget($targetname, '',
                        'interface-name' => $servername,
                        'long-desc'      => "Real Server $servername ($serverip) Port $serverport1",
                        'short-desc'     => "Real Server $servername-$serverport1",
                        'target-type'    => 'foundry-real-server-port',
                        'order'          => $opts->{order},
                    );
    $opts->{order} -= 1;
  }
  
    $result = rehash (%snL4VirtualServerPortTable);
  
  foreach my $row (sort keys %{$result}) {
    my ($servername, $serverport, $adminstate) = ($result->{$row}->{2}, $result->{$row}->{3}, $result->{$row}->{4});
    my ($serverport1) = ($serverport == "65535")?"default":$serverport;
    next unless (defined $adminstate && $adminstate == 1);
    my $serverip = $virtuals{$servername};
    my $targetname = 'slb_' . $serverip . '.' . $serverport1;
    $file->writetarget($targetname, '',
                        'interface-name' => $servername,
                        'long-desc'      => "Virtual Server $servername ($serverip) Port $serverport1",
                        'short-desc'     => "Virtual Server $servername-$serverport1",
                        'target-type'    => 'foundry-virtual-server-port',
                        'order'          => $opts->{order},
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
#      options refrence
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

sub rehash (@) {
  my %a = @_;
  my $b = {};
  my $row;

  foreach my  $index (keys %a) {
    my ($i, $j) = split (/\./, $index, 2);
    $b->{$j}->{$i} = $a{$index};
  }
  return $b;
}
1;
