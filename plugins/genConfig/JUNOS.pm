# -*-perl-*-
#    genDevConfig JUNOS plugin module
#
#    Copyright (C) 2003 Cougar < cougar @ random . ee >
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

package JUNOS;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

### Start package init

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);

my $VERSION = 1.04;

### End package init


###############################################################################
# These are device types we can handle in this plugin
# the names should be contained in the sysdescr string
# returned by the devices. The name is a regular expression.
###############################################################################
my @types = (
	'Juniper M\d+ router',
	'Juniper m\d+ Internet Backbone Router',
	'Juniper Networks, Inc. m\d+ internet router'
);

# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
my %OIDS = (

	### mib-jnx-mpls.txt (original by Kevin Stewart 8 Jan 2002)

	'mplsLspName'			=>	'1.3.6.1.4.1.2636.3.2.3.1.1',
	'mplsLspOctets'			=>	'1.3.6.1.4.1.2636.3.2.3.1.3',
	'mplsLspPackets'		=>	'1.3.6.1.4.1.2636.3.2.3.1.4',

	### mib-jnx-firewall.txt

	'jnxFWCounterDisplayFilterName'	=>	'1.3.6.1.4.1.2636.3.5.2.1.6',
	'jnxFWCounterDisplayName'	=>	'1.3.6.1.4.1.2636.3.5.2.1.7',
	'jnxFWCounterDisplayType'	=>	'1.3.6.1.4.1.2636.3.5.2.1.8',

	### mib-jnx-chassis.txt

#	'jnxBoxSerialNo'		=>	'1.3.6.1.4.1.2636.3.1.3.0',

	'jnxContainersIndex'		=>	'1.3.6.1.4.1.2636.3.1.6.1.1',
	'jnxContentsSerialNo'		=>	'1.3.6.1.4.1.2636.3.1.8.1.7',
	'jnxContentsRevision'		=>	'1.3.6.1.4.1.2636.3.1.8.1.8',
	'jnxContentsPartNo'		=>	'1.3.6.1.4.1.2636.3.1.8.1.10',

	'jnxOperatingDescr'		=>	'1.3.6.1.4.1.2636.3.1.13.1.5',
	'jnxOperatingState'		=>	'1.3.6.1.4.1.2636.3.1.13.1.6',
	'jnxOperatingMemory'		=>	'1.3.6.1.4.1.2636.3.1.13.1.15',

	'jnxFruType'			=>	'1.3.6.1.4.1.2636.3.1.15.1.6'
);

my %jnxFruType_d = (
	'1'	=>	'other',
	'2'	=>	'clockGenerator',
	'3'	=>	'flexiblePicConcentrator',
	'4'	=>	'switchingAndForwardingModule',
	'5'	=>	'controlBoard',
	'6'	=>	'routingEngine',
	'7'	=>	'powerEntryModule',
	'8'	=>	'frontPanelModule',
	'9'	=>	'switchInterfaceBoard',
	'10'	=>	'processorMezzanineBoardForSIB',
	'11'	=>	'portInterfaceCard',
	'12'	=>	'craftInterfacePanel',
	'13'	=>	'fan'
);

###############################################################################
### Private variables
###############################################################################

#my $snmp;

my $script = "JUNOS genDevConfig Module";

###############################################################################
###############################################################################

#-------------------------------------------------------------------------------
# plugin_name
# IN : N/A
# OUT: returns name of the plugin
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
        return 1 if ($opts->{sysDescr} =~ m/$type/gi)
        # Example of alternate method
        #$type =~ s/\./\\\./g; # Use this to escape dots for pattern matching
        #return ($opts->{sysObjectID} =~ m/$type/gi)
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

	$opts->{vendor_descr_oid} = "ifAlias";

	($opts->{vendor_soft_ver}) = 
	  ($opts->{sysDescr} =~ m/Version\s+([\d\.]+)\(\d/o) if ($opts->{sysDescr} =~ m/Version\s+([\d\.]+)\(\d/o);
	($opts->{vendor_soft_ver}) = ($opts->{sysDescr} =~ m/kernel JUNOS\s+([^\s]+)/) if ($opts->{sysDescr} =~ m/kernel JUNOS\s+([^\s]+)/);

	if (($opts->{sysDescr} =~ /Juniper M\d+ router/) ||
	    ($opts->{sysDescr} =~ /Juniper m\d+ Internet Backbone Router/) ||
	    ($opts->{sysDescr} =~ /Juniper Networks, Inc. m\d+ internet router/)) {
		($opts->{model}) = $opts->{sysDescr} =~ / (m\d+) /i;
		Info("Found an JUNOS device: model: $opts->{model}");
	}

	$opts->{chassisttype} = 'juniper-generic';
	$opts->{chassisname} = 'chassis-juniper';
	$opts->{usev2c} = 1 if ($opts->{req_usev2c});

	# Default feature promotions for JUNOS Devices
	$opts->{juniperbox} = 1 if ($opts->{req_vendorbox});
	$opts->{juniperint} = 1 if ($opts->{req_vendorint});
        $opts->{extendedint} = 0   if ($opts->{req_extendedint});
        $opts->{class} = 'juniper';

	# Don't create default chassis target
	#$opts->{chassisstats} = 0;
        # Note from Francois Mikus. Do create it! This is where
	# we store all user configurable options. Even if no DS's are collected.

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

	my %jnx_box = gettable('jnxOperatingDescr');

	if (keys(%jnx_box)) {
		my $key;
		my ($containerindex, $l1index, $l2index, $l3index);
		my $filename;
		my ($sdesc, $ldesc);
		my $target;
		my $ttype;

		my %operstate = gettable('jnxOperatingState');
		my %serialno = gettable('jnxContentsSerialNo');
		my %revno = gettable('jnxContentsRevision');
		my %partno = gettable('jnxContentsPartNo');
		my %frutype = gettable('jnxFruType');
		my %opermem = gettable('jnxOperatingMemory');

		foreach $key (sort keys(%jnx_box)) {
			next if ($operstate{$key} != 2);

			($containerindex, $l1index, $l2index, $l3index) = split /\./, $key;

			my $frutyped = $jnxFruType_d{$frutype{$key}} if (defined $frutype{$key});

			if ($jnx_box{$key} eq 'midplane') {
				next;
			} elsif ($jnx_box{$key} eq 'backplane') {
				$ttype = 'backplane';
			} elsif (!defined($frutyped)) {
				next;
			} elsif ($frutyped eq 'powerEntryModule') {
				$ttype = 'powersupply';
			} elsif ($frutyped eq 'controlBoard') {
				$ttype = 'ssb';
			} elsif ($frutyped eq 'flexiblePicConcentrator') {
				$ttype = 'fpc';
			} elsif ($frutyped eq 'portInterfaceCard') {
				$ttype = 'pic';
			} elsif ($frutyped eq 'routingEngine') {
				$ttype = 're';
			} else {
				next;
			}

			$target = "chassis_" . $key;

			$sdesc = "$jnx_box{$key}";
			$sdesc .= " ($opermem{$key} MB)" if ($opermem{$key});

			$ldesc = "$jnx_box{$key}";
			$ldesc .= "<BR>Serial number: $serialno{$key}" if ($serialno{$key} ne "");
			$ldesc .= "<BR>Revision: $revno{$key}" if ($revno{$key} ne "");
			$ldesc .= "<BR>Part number: $partno{$key}" if ($partno{$key} ne "");
			$ldesc .= "<BR>Installed memory: $opermem{$key} MB" if ($opermem{$key});

			my @config = ();

			push(@config,
				'order'		=>	$opts->{order},
				'display-name'	=>	"%devicename% chassis",
				'short-desc'	=>	$sdesc,
				'long-desc'	=>	$ldesc,
				'inst'		=>	0,
				'rest'		=>	$key,
				'target-type'	=>	'juniper-chassis-' . $ttype,
			);
			$file->writetarget($target , '', @config);

			$opts->{order} -= 1;
		}
	}


	my %jnx_fwfilters = gettable('jnxFWCounterDisplayFilterName');

	if (keys(%jnx_fwfilters)) {
		my $key;
		my $filter;
		my $lastfilter = "";
		my $filterdec;

		my %jnx_fwcounters = gettable('jnxFWCounterDisplayName');
		my %jnx_fwtypes = gettable('jnxFWCounterDisplayType');

		foreach $key (sort keys(%jnx_fwfilters)) {
			my $filter = $jnx_fwfilters{$key};

			if ($filter ne $lastfilter) {
				($filterdec = $filter) =~ s/(.)/("." . ord($1))/eg;
				$filterdec = length($filter) . $filterdec;
			}
			$lastfilter = $filter;

			my $counter = $jnx_fwcounters{$key};
			(my $counterdec = $counter) =~ s/(.)/("." . ord($1))/eg;
			$counterdec = length($counter) . $counterdec;

			my $ttype;
			if ($jnx_fwtypes{$key} == 2) {
				$ttype = "counter";
			} elsif ($jnx_fwtypes{$key} == 3) {
				$ttype = "policer";
			} else {
				Error ("Unknown jnxFWCounter type $jnx_fwtypes{$key}, please FIX!");
				next;
			}

			my $target = "firewall_${filter}_${counter}";
			my $sdesc = "$ttype: $filter - $counter";
			my $ldesc = "$ttype:<BR>Filter: $filter<BR>Counter: $counter";

			my @config = ();

			push(@config,
				'order'		=>	$opts->{order},
				'display-name'	=>	"%devicename% $filter  $counter",
				'short-desc'	=>	$sdesc,
				'long-desc'	=>	$ldesc,
				'inst'		=>	0,
				'filtername'	=>	$filterdec,
				'countername'	=>	$counterdec,
				'fwtype'	=>	$jnx_fwtypes{$key},
				'target-type'	=>	'juniper-firewall-' . $ttype,
			);
			$file->writetarget($target , '', @config);

			$opts->{order} -= 1;
		}
	}

	### Build Juniper MPLS Tunnel statistics

	my %junipermplslspname = gettable('mplsLspName');

	if (keys(%junipermplslspname)) {
		my $key;

		foreach $key (keys(%junipermplslspname)) {
			my @config = ();
			push(@config,
				'tunnel-name'	=>	$junipermplslspname{$key},
				'inst'		=>	"\"(\'$key\')\"",
				'order'		=>	$opts->{order},
				'interface-name'=>	'%tunnel-name%',
				'long-desc'	=>	'%tunnel-name%',
				'target-type'	=>	'juniper-mpls-tunnel'
			);
			$file->writetarget($junipermplslspname{$key}, '', @config);
		}
		$opts->{order} -= 1;
	}

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

	if ($iftype{$index} == 32 &&  $ifdescr{$index} =~ /\.\d+$/) {

		push(@config, 'target-type' => 'juniper-sub-interface' . $hc);
		$match = 1;

		$ifmtu{$index} = 1 if (!defined($ifmtu{$index}) || $ifmtu{$index} == 0);

	} elsif ($iftype{$index} == 6 &&  $ifdescr{$index} =~ /^fxp\d/) {

		push(@config, 'target-type' => 'juniper-standard-interface-hc');
		$match = 1;

	} elsif ($iftype{$index} == 37) {

		push(@config, 'target-type' => 'juniper-atm-interface-hc');
		$match = 1;

	}  elsif ($iftype{$index} == 135) {

		### VLANs

		push(@config, 'target-type' => 'juniper-sub-interface-hc');
		$match = 1;

	}  elsif ($opts->{juniperint}) {

		push(@config, 'target-type' => 'juniper-interface-hc');
		$match = 1;
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
