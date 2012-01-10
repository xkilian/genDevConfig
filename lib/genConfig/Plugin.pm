package genConfig::Plugin;

use strict;

use Common::Log;
use genConfig::Utils;
use genConfig::File;
use genConfig::SNMP;



###############################################################################
# usage - Give help info for the plugin.  Exit when done.
#         This may be reimplemented by subclasses, if needed.
###############################################################################

sub usage {
    my($self) = @_;

    print STDERR <<EOD;
No help available for the $self->{class} plugin.
EOD

    exit(0);
}

###############################################################################
# parse_flags -  Parse through flags given to the plugin.
#                This may be reimplemented by subclasses, if needed.
#                popts is a ref to a hash of arrays.  Hash keys are flags, the
#                arrays hold the values.
###############################################################################

sub parse_flags {
    my($self, $popts) = @_;

    foreach my $arg (keys %{$popts}) {
	if ($arg eq 'h' || $arg eq 'help') {
	    $self->usage();
	} else {
	    Error ("Unknown flag: $arg\n");
	    exit(1);
	}
    }
}


###############################################################################
# init -  Do any needed internal initialization.
#         This may be reimplemented by subclasses, if needed.
###############################################################################

sub init {
    my($self) = @_;
}

###############################################################################
# can_handle  - Return true if this plugin can handle the current device.
#               This is a class method.  (no sense of self)
#               This MUST be reimplemented by subclasses.
###############################################################################

sub can_handle { 0; }

###############################################################################
# discover  - Gather any special info needed by the plugin.
#             This may be reimplemented by subclasses, if needed.
###############################################################################

sub discover { 
    my($self, $opts) = @_;
}

###############################################################################
# custom_targets - Generate custom targets for the current device.
#                  This may be reimplemented by subclasses, if needed.
###############################################################################

sub custom_targets {
    my ($self, $data, $opts) = @_;
}

###############################################################################
# custom_interfaces -  Customize interface targets for the current device.
#                      This may be reimplemented by subclasses, if needed.
###############################################################################

sub custom_interfaces {
    my ($self,$index,$data,$opts) = @_;
}

###############################################################################
# custom_files -  Generate custom files for the current device.
#                 This may be reimplemented by subclasses, if needed.
###############################################################################

sub custom_files {
    my ($self,$data,$opts) = @_;
}

###############################################################################
# new  - Instantiate a plugin object and send any flags to parse_flags.
#        This may be reimplemented by subclasses, but is probably better left
#        as is.
###############################################################################

sub new {
    my($class, $popts) = @_;

    my $self = bless {class => $class}, $class;

    $self->init();
    $self->parse_flags($popts);

    return $self;
}

###############################################################################

1;
