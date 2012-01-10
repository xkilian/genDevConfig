# -*-perl-*-
#    genDevConfig plugin module
#
#    Copyright (C) 2004 Mike Fisher
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

package NetSNMP;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;

use genConfig::Plugin;

our @ISA = qw(genConfig::Plugin);


### Start package init

my $VERSION = 1.01;

### End package init


###############################################################################
# These are the OIDS used by this plugin
# the OIDS should only be those necessary for index mapping or
# recognizing if a feature is supported or not by the device.
###############################################################################

my %OIDS = (

	    netSnmpAgentOIDs         => '1.3.6.1.4.1.8072.3.2',
	    #
	    hrSystemNumUsers         => '1.3.6.1.2.1.25.1.5',    # .0
	    hrSystemProcesses        => '1.3.6.1.2.1.25.1.6',    # .0

	    hrStorageType            => '1.3.6.1.2.1.25.2.3.1.2',
	    hrStorageName            => '1.3.6.1.2.1.25.2.3.1.3',
	    hrStorageAllocationUnits => '1.3.6.1.2.1.25.2.3.1.4',
	    hrStorageSize            => '1.3.6.1.2.1.25.2.3.1.5',
	    hrStorageUsed            => '1.3.6.1.2.1.25.2.3.1.6',

	    hrFSMountPoint           => '1.3.6.1.2.1.25.3.8.1.2',
	    hrFSType                 => '1.3.6.1.2.1.25.3.8.1.4',
	    hrFSStorageIndex         => '1.3.6.1.2.1.25.3.8.1.7',
	    ### hrFSStorageIndex may be busted in Net-SNMP 5.1...

	    # Load averages.
	    ucd_loadTable        => '1.3.6.1.4.1.2021.10.1.3',
	    ucd_load1min         => '1.3.6.1.4.1.2021.10.1.3.1',
	    ucd_load5min         => '1.3.6.1.4.1.2021.10.1.3.2',
	    ucd_load15min        => '1.3.6.1.4.1.2021.10.1.3.3',
	    
	    # Memory stats
	    ucd_memswapAvail     => '1.3.6.1.4.1.2021.4.4.0',
	    ucd_memrealAvail     => '1.3.6.1.4.1.2021.4.6.0',
	    ucd_memtotalAvail    => '1.3.6.1.4.1.2021.4.11.0',
	    
	    # Disk stats (Don't forget the instance number...)
	    ucd_diskfree         => '1.3.6.1.4.1.2021.9.1.7',
	    ucd_diskused         => '1.3.6.1.4.1.2021.9.1.8',
	    ucd_diskpused        => '1.3.6.1.4.1.2021.9.1.9',
	    
	    # CPU Stats
	    ucd_cpuUser          => '1.3.6.1.4.1.2021.11.9.0',
	    ucd_cpuSystem        => '1.3.6.1.4.1.2021.11.10.0',
	    ucd_cpuIdle          => '1.3.6.1.4.1.2021.11.11.0',
	    ucd_rawCpuUser       => '1.3.6.1.4.1.2021.11.50.0',
	    ucd_rawCpuNice       => '1.3.6.1.4.1.2021.11.51.0',
	    ucd_rawCpuSystem     => '1.3.6.1.4.1.2021.11.52.0',
	    ucd_rawCpuIdle       => '1.3.6.1.4.1.2021.11.53.0',
	    
	    # Disk I/O
	    ucd_diskIODevice     => '1.3.6.1.4.1.2021.13.15.1.1.2',
	    ucd_diskIONRead      => '1.3.6.1.4.1.2021.13.15.1.1.3',
	    ucd_diskIONWrite     => '1.3.6.1.4.1.2021.13.15.1.1.4',
	    ucd_diskIOReads      => '1.3.6.1.4.1.2021.13.15.1.1.5',
	    ucd_diskIOWrites     => '1.3.6.1.4.1.2021.13.15.1.1.6',

      );

my @EXCLUDEFS = qw(^/proc ^/home(/.*)? ^/vol);
my @INCLUDEFS = ();

my @EXCLUDEIO = ();

###############################################################################
### Private variables
###############################################################################

my $script = "NetSNMP genDevConfig Module";

###############################################################################
# plugin_name - Provide the name of the plugin
###############################################################################

sub plugin_name {
    my $self = shift;
    return $script;
}

###############################################################################
# usage - Give help info for the plugin.  Exit when done.
###############################################################################

sub usage {
    my($self) = @_;

    print STDERR <<EOD;
$self->{class} options:

    h                     - Print module help info and exit.
    help
    excludefs=<regex>     - Exclude any filesystem matching the regex from 
                            the config. Can be used multiple times.
    includefs=<regex>     - Explicitly include any filesystem matching the
                            regex in the config.  This can be used to override
			    implicit or explicit exculdes. Can be used 
			    multiple times.
    excludeio=<regex>     - Explicitly exclude any io objects matching the
                            regex. Can be used multiple times.
    nodiskio              - Don't generate disk I/O targets.
    nofsstats             - Don't generate filesystem targets.

EOD

    exit(0);
}

###############################################################################
# parse_flags -  Parse through flags given to the plugin.
###############################################################################

sub parse_flags {
    my($self, $popts) = @_;

    foreach my $arg (keys %{$popts}) {
	if ($arg eq 'h' || $arg eq 'help') {
	    $self->usage();
	} elsif ($arg eq 'excludefs') {
	    push(@{$self->{excludefs}}, @{$popts->{excludefs}});
	} elsif ($arg eq 'includefs') {
	    push(@{$self->{includefs}}, @{$popts->{includefs}});
	} elsif ($arg eq 'excludeio') {
	    push(@{$self->{excludeio}}, @{$popts->{excludeio}});
	} elsif ($arg eq 'nodiskio') {
	    $self->{nodiskio} = 1;
	} elsif ($arg eq 'nofsstats') {
	    $self->{nofsstats} = 1;
	} else {
	    Error ("Unknown flag: $arg\n");
	    exit(1);
	}
    }
}

###############################################################################
# init -  Do any needed internal initialization.
###############################################################################

sub init {
    my($self) = @_;

    $self->{excludefs} = [@EXCLUDEFS];
    $self->{includefs} = [@INCLUDEFS];
    $self->{excludeio} = [@EXCLUDEIO];
}

###############################################################################
# can_handle
# IN : ref to options hash
# OUT: return true or false
###############################################################################

sub can_handle {
    my($self, $opts) = @_;

    my $oid = $OIDS{netSnmpAgentOIDs};
    $oid =~ s/\./\\\./g;

    return ($opts->{sysObjectID} =~ /^$oid/);

}


###############################################################################
# discover
# IN : options hash
# OUT: returns the model and options hash
###############################################################################

sub discover {
    my($self, $opts) = @_;

    ### Add our OIDs to the the global OID list

    register_oids(%OIDS);

    ### Parse flags given to the plugin.

    self->parse_flags($opts->{pluginflags});

    ###
    ### START DEVICE DISCOVERY SECTION
    ###

    # Default feature promotions for NetSNMP Devices
    $opts->{netsnmpbox} = 1  if ($opts->{req_vendorbox});
    $opts->{namedonly} = 1   if ($opts->{req_namedonly});
    $opts->{usev2c} = 1      if ($opts->{req_usev2c});

    my %rawCpuNice = gettable('entPhysicalDescr');    

    if (!keys %rawCpuNice) {
        $opts->{chassisttype} = 'generic-box-netsnmp-nonice';
        $opts->{chassisname}  = 'Host';
        $opts->{model}        = '*nix box';
    } else {
        $opts->{chassisttype} = 'generic-box-netsnmp';
        $opts->{chassisname}  = 'Host';
        $opts->{model}        = '*nix box';
    }

    return;
}

###############################################################################
# custom_targets
# IN : options hash
# OUT: returns the options hash
###############################################################################

sub custom_targets {
    my ($self, $data, $opts) = @_;
        
    ###
    ### DEVICE CUSTOM CONFIG SECTION
    ###

    my $file = $opts->{'file'};

    $file->writetarget("$opts->{devicename}_system", '',
		       'display-name'   => '%devicename%  OS environment',
		       'target-type'    => 'hr_System',
		       'inst'           => '',
		       'order'          => $opts->{order}--,
		       );

    ### Gen UCD Disk IO targets...

    $self->do_diskio($data, $opts) if (!defined $self->{nodiskio});

    ### Gen Host Resource Storage targets...

    $self->do_hrstorage($data, $opts) if (!defined $self->{nofsstats});


}


###############################################################################
###############################################################################
# Private functions below
###############################################################################
###############################################################################

sub do_diskio {
    my ($self, $data, $opts) = @_;

    ### See if there's anything there...

    my %diskIODevice = gettable('ucd_diskIODevice');

    return if (!keys %diskIODevice);

    my $multilev = $opts->{req_modular};

    my $dsply = $multilev ? "%device%" : "disk %device%";
	
    my @defargs = ('target-type'  => "ucd_diskio",
		   'display-name' => $dsply,
		   'inst'         => "map(ucd-diskio-device)",
		   );

    ### If the user requested a hierarchical setup, then create it and 
    ### write a default target to avoid repeating the default args over 
    ### and over.
    ### Otherwise use the existing file and repeat the default args.

    my $subf;
    if ($multilev) {
	my $subdir = "$opts->{rdir}/diskio";

	subdir($subdir, $opts->{lowercase});
	$subf = new genConfig::File("$subdir/targets");

	$subf->writetarget('--default--', '', @defargs,
			   'directory-desc' => 'Per disk I/O statistics',
			   );

	@defargs = ();

    } else {
	$subf = $opts->{'file'};
    }

    ### Write out the targets.


    foreach my $d (sort {alpha_num($diskIODevice{$a},$diskIODevice{$b})} 
		   keys %diskIODevice) {
	next if grep({$diskIODevice{$d} =~ m|$_|} @{$self->{excludeio}});
	my $target = "disk_$diskIODevice{$d}";
	$target =~ s|/|_|g;

	$subf->writetarget($target, '', @defargs,
			   'device' => $diskIODevice{$d},
			   'order'  => $opts->{order}--
			   );
    }

    ### If we openned a new file, then close it...

    if ($multilev) {
	$subf->close();
    }
}

###############################################################################

sub do_hrstorage {
    my ($self, $data, $opts) = @_;

    ### See if there's anything there...

    my %sName  = gettable('hrStorageName');

    return if (!keys %sName);

    my %sType  = gettable('hrStorageType');
    my %sUnits = gettable('hrStorageAllocationUnits');
    my %sSize  = gettable('hrStorageSize');

    my @defargs = ('target-type'  => "hr_Storage",
		   'display-name' => "%storage%",
		   'inst'         => "map(hr-storage-name)",
		   'min-size'     => "%blksize%",
		   'units'        => "%blksize%,*",
		   );

    my $multilev = $opts->{req_modular};

    ### If the user requested a hierarchical setup, then create it and 
    ### write a default target to avoid repeating the default args over 
    ### and over.
    ### Otherwise use the existing file and repeat the default args.

    my $subf;
    if ($multilev) {

	my $subdir = "$opts->{rdir}/filesystems";

	subdir($subdir, $opts->{lowercase});
	$subf = new genConfig::File("$subdir/targets");

	$subf->writetarget('--default--', '', @defargs,
			   'directory-desc' => 'File system statistics',
			   );
	
	@defargs = ();

    } else {
	$subf = $opts->{'file'};

    }

    ### Write out the targets.

    foreach my $f (sort {alpha_num($sName{$a},$sName{$b})} keys %sName) {

	### Skip anything that's not a "fixed disk", has 0 size, or is 
	### listed in excludefs.

	next if ($sType{$f} !~ /\.4$/ ||
		 !$sSize{$f} ||
		 (grep({$sName{$f} =~ m|$_|} @{$self->{excludefs}}) &&
		  !grep({$sName{$f} =~ m|$_|} @{$self->{includefs}})));

	my $target = $sName{$f};
	$target =~ s|/|_|g;

	$subf->writetarget($target, '', @defargs,
			   'max-size'  => ($sSize{$f} * $sUnits{$f}) * 1.05,
			   'storage'   => $sName{$f},
			   'blksize'   => $sUnits{$f},
			   'order'     => $opts->{order}--,
			   );
    }

    ### If we openned a new file, then close it...

    if ($multilev) {
	$subf->close();
    }
}

###############################################################################

sub alpha_num {
    my($a, $b) = @_;

    if ($a =~ /(\d+)$/ && $b =~ /(\d+)$/) {
	my($a2) = $a =~ /(\d+)$/;
	my $a1 = $`;
	my($b2) = $b =~ /(\d+)$/;
	my $b1 = $`;
	return($a1 cmp $b1 || $a2 <=> $b2);
    } else {
	return($a cmp $b);
    }
}

###############################################################################


1;
