# AUR-vs-Jenkins
Takes a list AUR Git Repos and Adds/Updates/Creates/Deletes Jenkins Jobs 

v0.2.0

Options:
* --verbose, -v, -V        Be chatty about operations ( NOT YET IMPLEMENTED )
* --dump_conf=some-project Dumps the XML Configuration used by Jenkins for the build
* --trigger, -t            After checking directory list and creating/deleting jobs, trigger build jobs for all known PKGBUILDs in the given directory path.

TODOs:
* Implement the verbose option
* Create a dummy yaml file with configuration options
* Right now only Jenkins host/auth is yaml managed, add options in the yaml for the AUR Root and the Build Directory where the Jobs will actually do the work, as to not pollute the aur git repos with build files.
