package genConfig::pluginUtils;

use strict;

use Common::Log;


#----------------------------------------------------------------------------- 
# find_plugin - Find one or more plugins to handle the current device.
#
# IN : the main script directory and a ref to the opt hash
# OUT: an empty array if no plugin was found, or
#      an array whose first element is the plugin object that will handle
#         the current device, or
#      an array of plugin names if multiple plugins can handle the current
#         device.
#----------------------------------------------------------------------------- 

sub find_plugin {
    my($rootdir, $opts) = @_;

    my $plugdir = $opts->{plugindir};
    my @plugins = ();


    ### Get a list of modules to check...

    my @plist;
    if ($opts->{plugin}) {
	@plist = ("$rootdir/$plugdir/$opts->{plugin}.pm");
    } else {
	@plist = (<$rootdir/$plugdir/*.pm>);
    }

    ### Go through the list...

    foreach (@plist) {

	### See if it's a valid perl module that we can load...

	eval {
	    require $_;
	};
	if ($@) {
	    Warn("Cannot load plugin $_ : $@");
	    next;
	}

	### See if it thinks it can handle the current device.  If so,
	### add it to the list.
	
	my($mod) = $_ =~ m|$plugdir/([^\.]+)\.pm|;
	$mod =~ s|/|::|g;
	
	eval {
	    if ("$mod"->can_handle($opts)) {
		push(@plugins, $mod);
	    }
	};
	Warn("$mod does not appear to be a valid plugin module.  ",
	     "Ignoring it. $@") if ($@);
    }

    ### If the list contains only one module name, instantiate an object
    ### using that module and return that instead.
    my @validplugins = ();

    foreach my $plugin (@plugins) {
	eval {
	    push (@validplugins,  $plugin->new($opts->{pluginflags}));
	};
	if ($@) {
	    Warn("$plugin does not appear to be a valid plugin module.  ",
		 "Ignoring it. $@");
	}
    }

    return @validplugins;
}


1;
