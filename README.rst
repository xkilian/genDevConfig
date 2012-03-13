genDevConfig is a configuration generator for collecting supervision data from networked devices.

genDevConfig version 2.x can create configuration profiles for the following network monitoring tools

	1. Cricket

genDevConfig version 3.x can create configuration profiles for the following networking tools :

	1. Nagios
	2. Shinken
	3. Icinga

genDevConfig version 3.x (this one) currently creates the Nagios compatible format. This is currently for development purposes.

TO DO:

 - DONE Have genDevConfig communicate with network devices and create a Nagios compatible configuration 
 - Convert the template from Cricket format to Shinken format
 - Create the python poller module that will use the configuration to efficiently poll SNMP enabled devices
 - Permit genDevConfig to import custom descriptions and configurations from CSV or INI based inputs
