#####################################################################################
# Copyright 2011 Normation SAS
#####################################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, Version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#####################################################################################


#
# Fetch the promises from the server to be available for others machines
# Must not do it on the RootServer though...


bundle agent propagatePromises
{

  vars:
    any::
      "server_data" string => "${server_info.policy_files}/share"; #actual directory with data to propagate
      "client_data" string => "${g.rudder_var}/share/";  #where to put the files on the client when downloaded

  files:
    root_server::
      "${g.rudder_dependencies}"
        copy_from    => copy("${g.rudder_base}/share/tools"),
        depth_search => recurse_visible("inf"),
        comment => "Fetching the tools for the promises execution",
        classes => if_else("tools_propagated", "could_not_propagate_tools");
    !root_server::
      "${client_data}"  #that's a loop on each files in client_inputs
        copy_from    => remote("${server_info.cfserved}","${server_data}"),
        depth_search => recurse_visible("inf"),
        comment => "Fetching the promises to propagate",
        classes => if_else("promises_propagated", "could_not_propagate_promise");

      "${g.rudder_dependencies}"
        copy_from    => remote("${server_info.cfserved}","${g.rudder_dependencies}"),
        depth_search => recurse_visible("inf"),
        comment => "Fetching the tools for the promises execution",
        classes => if_else("tools_propagated", "could_not_propagate_tools");

      "${sys.workdir}/masterfiles"
        copy_from    => remote("${server_info.cfserved}","${sys.workdir}/masterfiles"),
        depth_search => recurse_visible("inf"),
        file_select => no_license_dat, #We don't want to propagate a wrong license.dat
        comment => "Fetching the bootstrap promises",
        classes => if_else("masterfiles_propagated", "could_not_propagate_masterfiles");

      "${sys.workdir}/masterfiles/license.dat"
        copy_from    => local_cp("${sys.workdir}/inputs/license.dat"),
        comment => "Putting the right license in the bootstrap",
        classes => if_else("license_copied", "could_not_copy_license");

  reports:
    # Success if files are updated or not changed (kept or repaired).
    # root server have only tools to be updated and others have tools,
    # promises, masterfiles folder and licenses to be updated.
    ((root_server.tools_propagated)|(!root_server.tools_propagated.promises_propagated.masterfiles_propagated.license_copied)).!(could_not_propagate_tools|could_not_propagate_promise|could_not_propagate_masterfiles|could_not_copy_license)::
      "@@DistributePolicy@@result_success@@&TRACKINGKEY&@@Propagate promises@@None@@${g.execRun}##${g.uuid}@#All files have been propagated";
    could_not_propagate_promise::
      "@@DistributePolicy@@result_error@@&TRACKINGKEY&@@Propagate promises@@None@@${g.execRun}##${g.uuid}@#Cannot propagate policy files";

    could_not_propagate_tools::
      "@@DistributePolicy@@result_error@@&TRACKINGKEY&@@Propagate promises@@None@@${g.execRun}##${g.uuid}@#Cannot propagate tools";

    could_not_propagate_masterfiles::
      "@@DistributePolicy@@result_error@@&TRACKINGKEY&@@Propagate promises@@None@@${g.execRun}##${g.uuid}@#Cannot propagate masterfiles";

    could_not_copy_license::
      "@@DistributePolicy@@result_error@@&TRACKINGKEY&@@Propagate promises@@None@@${g.execRun}##${g.uuid}@#Cannot copy local license";
}

# Sending the inventory to cmdb (or syncing with the server if we are a simple relay)
bundle agent sendInventoryToCmdb
{

  files:

    root_server::

      "${g.rudder_inventories}/incoming"
        transformer => "${g.rudder_dependencies}/send-clean.sh &CMDBENDPOINT& ${this.promiser} ${g.rudder_inventories}/received/",
        depth_search => recurse_visible(1),
        file_select => all_files,
        classes => if_else("inventory_sent", "cant_send_inventory"),
        comment => "Sending the inventory to the cmdb";

      "${g.rudder_inventories}/accepted-nodes-updates"
        transformer => "${g.rudder_dependencies}/send-clean.sh &CMDBENDPOINT& ${this.promiser} ${g.rudder_inventories}/received/",
        depth_search => recurse_visible(1),
        file_select => all_files,
        classes => if_else("inventory_sent", "cant_send_inventory"),
        comment => "Sending the inventory to the cmdb";


# NEED TO DO THE RSYNC PART

  reports:
    inventory_sent.!cant_send_inventory::
      "@@DistributePolicy@@result_success@@&TRACKINGKEY&@@Send inventories to CMDB@@None@@${g.execRun}##${g.uuid}@#Incoming inventories were successfully added to Rudder";
    cant_send_inventory::
      "@@DistributePolicy@@result_error@@&TRACKINGKEY&@@Send inventories to CMDB@@None@@${g.execRun}##${g.uuid}@#Some inventories failed to add successfully to Rudder";
    !inventory_sent::
      "@@DistributePolicy@@result_success@@&TRACKINGKEY&@@Send inventories to CMDB@@None@@${g.execRun}##${g.uuid}@#No inventory to send";
}


body file_select all_files
{
        leaf_name => { ".*\..*" };
        file_result => "leaf_name";
}


body file_select no_license_dat
{
        leaf_name => { "license\.dat" };
        file_result => "!leaf_name";
}
