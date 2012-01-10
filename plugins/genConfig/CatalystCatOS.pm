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

package CatalystCatOS;

use strict;

### Start package init

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.04;

### End package init

# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.

my @types = ('Catalyst\sOperating\sSystem',
            );

# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.

my %OIDS = (
	    ### from CISCO Catalyst MIB

	    'cseL2ForwardedTotalPkts'   => '1.3.6.1.4.1.9.9.97.1.1.1.1.3',
	    'portIfIndex'               => '1.3.6.1.4.1.9.5.1.4.1.1.11',
	    'portName'                  => '1.3.6.1.4.1.9.5.1.4.1.1.4',
	    'portAdminSpeed'            => '1.3.6.1.4.1.9.5.1.4.1.1.9',
	    'portDuplex'                => '1.3.6.1.4.1.9.5.1.4.1.1.10',
           );

### Misc private stuff...

my %l2stats;
my $script = "Catalyst CatOS genDevCOnfig plugin";

my @DuplexTable = ( "Half", "Full", "Disagree", "Auto" );

my %SpeedTable = ( 1 => "autoDetect" ,
                                4000000       => "4 Mbps",
                                10000000     => "10 Mbps",
                                16000000     => "16 Mbps",
                                45000000     => "45 Mbps",
                                64000000     => "64 Mbps",
                                100000000   => "100 Mbps",
                                155000000   => "155 Mbps",
                                400000000   => "400 Mbps",
                                622000000   => "622 Mbps",
                                1000000000 => "1 Gbps",
                                1544000       => "1.544 Mbps",
                                2000000       => "2 Mbps",
                                2048000       => "2.048 Mbps",
                                64000           => "64 kps",
                                10                => "10 Gps"
	);

###############################################################################
# plugin_name
# IN : N/A
# OUT: returns plugin name
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

###############################################################################

sub can_handle {
    my($self, $opts) = @_;
    
    return (grep { $opts->{'sysDescr'} =~ m/$_/gi } @types);

}

###############################################################################
# discover
# IN : ref to options hash
# OUT: n/a
###############################################################################

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the global list

    register_oids(%OIDS);

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    $opts->{'catalystbox'} = 1;
    $opts->{'model'} = 'CatOS-Generic';
    $opts->{'class'} = 'catalyst';
    $opts->{'vendor_descr_oid'} = 'portName';
    $opts->{'inst'} = 'map(module-port)';
    $opts->{catalystint} = 1 if ($opts->{req_vendorint});
    $opts->{extendedint} = 0    if ($opts->{req_extendedint});
    $opts->{usev2c} = 1 if ($opts->{req_use2c});

    # if $opts{'vendor_soft_ver'} ge "???";

    return;
}


###############################################################################
# custom_targets
# IN : ref to options hash
# OUT: n/a
###############################################################################

sub custom_targets {
    my($self, $data, $opts) = @_;

    # Saving local copies of runtime data
    my %ifspeed    = %{$data->{ifspeed}};
    my %ifdescr    = %{$data->{ifdescr}};
    my %intdescr   = %{$data->{intdescr}};
    my %iftype     = %{$data->{iftype}};
    my %ifmtu      = %{$data->{ifmtu}};
    my %slotPortMapping   = %{$data->{slotPortMapping}};
    my %slotPortList      = %{$data->{slotPortList}};
    my %slotNameList      = %{$data->{slotNameList}};
    my %slotList          = %{$data->{slotList}};

    ###
    ### DEVICE CUSTOM CONFIG SECTION
    ###

    ### Build a Slot/Port Mapping that is vendor independant

    my %portifindex = reverse gettable('portIfIndex');

    my %portAdminSpeed = gettable('portAdminSpeed');

    my %portDuplex = gettable('portDuplex');

    foreach my $index (keys %portifindex) {
        ### This is "module.port".
        my ($s, $p) = split (/\./,$portifindex{$index});
        ### Map the port/slot to standard format slot/port
        $slotPortMapping{$index} = "$s/$p";
        ### Rename the interface description to something useful
        $ifdescr{$index} = "port$s\_$p";

	Debug("XXX: $index $portifindex{$index} ");
	
	Debug("XXX: Admin Speed $portAdminSpeed{$portifindex{$index}}");
	Debug("XXX: Duplex $portDuplex{$portifindex{$index}}");

        ### Build a mapping between the portName and the ifIndex index.
        $intdescr{$index} = $intdescr{$portifindex{$index}};
        $intdescr{$index} .= "<BR>Admin Speed $SpeedTable{$portAdminSpeed{$portifindex{$index}}}<BR>Duplex $DuplexTable[$portDuplex{$portifindex{$index}}-1]($portDuplex{$portifindex{$index}})<BR>";
        ### Build a mapping between the ifDescr and its associated Slot.
	Debug("XXX: \$slotPortList{$ifdescr{$index}} = $s;");
        $slotPortList{$ifdescr{$index}} = $s;
        ### Build a mapping between the Slot number and its name.
	Debug(qq(XXX: \$slotNameList{$s} = "Slot_$s";));
        $slotNameList{$s} = "Slot_$s";
        ### Build a list of existing slots.
        $slotList{$s}++;
    }

    ### Try and get layer 2 switch engine stats.

    %l2stats = gettable('cseL2ForwardedTotalPkts');

    if (%l2stats) {
        my $file = $opts->{file};
  
        foreach my $key (keys(%l2stats)) {
	        Info("KeyL2Stats: $key\n"); 
        }

        my $ldesc = 'Layer2 engine statistics - total switched packets';
        my $targetname = 'layer2engine';
    
        $file->writetarget($targetname, '',
			       'order'         =>      $opts->{order},
			       'inst'          =>      (keys %l2stats)[0],
			       'display-name'  =>      $targetname,
			       'short-desc'    =>      $ldesc,
			       'long-desc'     =>      $ldesc,
			       'target-type'   =>      'switch-layer2');
    
        $opts->{order} -= 1;
    }

    if ($opts->{catalystbox}) {
        my $file = $opts->{file};

        my ($ldesc, $sdesc);
        $ldesc = "Switch cpu statistics";
        $sdesc = "Switch cpu statistics";
        my ($targetname) = 'switch-cpu';

        $file->writetarget($targetname, '',
            'inst'           => 'map(cpu-stats)',
            'order'           => $opts->{order},
            'interface-name'   => $targetname,
            'long-desc'   => $ldesc,
            'short-desc'  => $sdesc,
            'target-type' => 'switch-cpu',
        );

        $opts->{order} -= 1;
    }

    if ($opts->{catalystbox}) {
        my $file = $opts->{file};

        my ($ldesc, $sdesc);
        $ldesc = "Switch memory statistics";
        $sdesc = "Switch memory statistics";
        my ($targetname) = 'switch-mem';

        $file->writetarget($targetname, '',
            'inst'           => 'map(mem-stats)',
            'order'           => $opts->{order},
            'interface-name'   => $targetname,
            'long-desc'   => $ldesc,
            'short-desc'  => $sdesc,
            'target-type' => 'switch-mem',
        );

        $opts->{order} -= 1;
    }

    # Saving return data of local copies of runtime data
    %{$data->{ifspeed}} = %ifspeed;
    %{$data->{ifdescr}} = %ifdescr;
    %{$data->{intdescr}} = %intdescr;
    %{$data->{iftype}} = %iftype;
    %{$data->{ifmtu}} = %ifmtu;
    %{$data->{slotPortMapping}} = %slotPortMapping;
    %{$data->{slotPortList}}    = %slotPortList;
    %{$data->{slotNameList}}    = %slotNameList;
    %{$data->{slotList}}        = %slotList;
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


    ### Collect extra info from Cisco Catalyst MIB

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
    $data->{match}  = $match;
    $data->{customsdesc} = $customsdesc;
    $data->{customldesc} = $customldesc;

    return;
}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# tab-width: 4
# perl-indent-level: 4
# End:
