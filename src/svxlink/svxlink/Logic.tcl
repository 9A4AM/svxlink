###############################################################################
#
# Generic Logic event handlers
#
###############################################################################

#
# This is the namespace in which all functions and variables below will exist.
#
namespace eval Logic {


#
# A variable used to store a timestamp for the last identification.
#
variable prev_ident 0;

#
# A constant that indicates the minimum time in seconds to wait between two
# identifications. Manual and long identifications is not affected.
#
variable min_time_between_ident 120;

#
# Short and long identification intervals. They are setup from config
# variables below.
#
variable short_ident_interval 0;
variable long_ident_interval 0;


#
# The ident_only_after_tx variable indicates if identification is only to
# occur after the node has transmitted. The variable is setup below from the
# configuration variable with the same name.
# The need_ident variable indicates if identification is needed.
#
variable ident_only_after_tx 0;
variable need_ident 0;

#
# A list of functions that should be called once every whole minute
#
variable timer_tick_subscribers [list];

#
# Contains the ID of the last receiver that indicated squelch activity
#
variable sql_rx_id 0;

#
# Executed when the SvxLink software is started
#
proc startup {} {
  #playMsg "Core" "online"
  #send_short_ident
}


#
# Executed when a specified module could not be found
#   module_id - The numeric ID of the module
#
proc no_such_module {module_id} {
  playMsg "Core" "no_such_module";
  playNumber $module_id;
}


#
# Executed when a manual identification is initiated with the * DTMF code
#
proc manual_identification {} {
  global mycall;
  global report_ctcss;
  global active_module;
  global loaded_modules;
  variable CFG_TYPE;
  variable prev_ident;

  set epoch [clock seconds];
  set hour [clock format $epoch -format "%k"];
  regexp {([1-5]?\d)$} [clock format $epoch -format "%M"] -> minute;
  set prev_ident $epoch;

  playMsg "Core" "online";
  spellWord $mycall;
  if {$CFG_TYPE == "Repeater"} {
    playMsg "Core" "repeater";
  }
  playSilence 250;
  playMsg "Core" "the_time_is";
  playTime $hour $minute;
  playSilence 250;
  if {$report_ctcss > 0} {
    playMsg "Core" "pl_is";
    playNumber $report_ctcss;
    playMsg "Core" "hz";
    playSilence 300;
  }
  if {$active_module != ""} {
    playMsg "Core" "active_module";
    playMsg $active_module "name";
    playSilence 250;
    set func "::";
    append func $active_module "::status_report";
    if {"[info procs $func]" ne ""} {
      $func;
    }
  } else {
    foreach module [split $loaded_modules " "] {
      set func "::";
      append func $module "::status_report";
      if {"[info procs $func]" ne ""} {
	$func;
      }
    }
  }
  playMsg "Default" "press_0_for_help"
  playSilence 250;
}


#
# Executed when a short identification should be sent
#   hour    - The hour on which this identification occur
#   minute  - The hour on which this identification occur
#
proc send_short_ident {{hour -1} {minute -1}} {
  global mycall;
  variable CFG_TYPE;

  spellWord $mycall;
  if {$CFG_TYPE == "Repeater"} {
    playMsg "Core" "repeater";
  }
  playSilence 500;
}


#
# Executed when a long identification (e.g. hourly) should be sent
#   hour    - The hour on which this identification occur
#   minute  - The hour on which this identification occur
#
proc send_long_ident {hour minute} {
  global mycall;
  global loaded_modules;
  global active_module;
  variable CFG_TYPE;

  spellWord $mycall;
  if {$CFG_TYPE == "Repeater"} {
    playMsg "Core" "repeater";
  }
  playSilence 500;

  playMsg "Core" "the_time_is";
  playSilence 100;
  playTime $hour $minute;
  playSilence 500;

    # Call the "status_report" function in all modules if no module is active
  if {$active_module == ""} {
    foreach module [split $loaded_modules " "] {
      set func "::";
      append func $module "::status_report";
      if {"[info procs $func]" ne ""} {
        $func;
      }
    }
  }

  playSilence 500;
}


#
# Executed when the squelch just have closed and the RGR_SOUND_DELAY timer has
# expired.
#
proc send_rgr_sound {} {
  variable sql_rx_id;

  playTone 440 500 100;
  playSilence 200;

  for {set i 0} {$i < $sql_rx_id} {incr i 1} {
    playTone 880 500 50;
    playSilence 50;
  }
  playSilence 100;
}


#
# Executed when an empty macro command (i.e. D#) has been entered.
#
proc macro_empty {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when an entered macro command could not be found
#
proc macro_not_found {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when a macro syntax error occurs (configuration error).
#
proc macro_syntax_error {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when the specified module in a macro command is not found
# (configuration error).
#
proc macro_module_not_found {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when the activation of the module specified in the macro command
# failed.
#
proc macro_module_activation_failed {} {
  playMsg "Core" "operation_failed";
}


#
# Executed when a macro command is executed that requires a module to
# be activated but another module is already active.
#
proc macro_another_active_module {} {
  global active_module;

  playMsg "Core" "operation_failed";
  playMsg "Core" "active_module";
  playMsg $active_module "name";
}


#
# Executed when an unknown DTMF command is entered
#   cmd - The command string
#
proc unknown_command {cmd} {
  spellWord $cmd;
  playMsg "Core" "unknown_command";
}


#
# Executed when an entered DTMF command failed
#   cmd - The command string
#
proc command_failed {cmd} {
  spellWord $cmd;
  playMsg "Core" "operation_failed";
}


#
# Executed when a link to another logic core is activated.
#   name  - The name of the link
#
proc activating_link {name} {
  playMsg "Core" "activating_link_to";
  spellWord $name;
}


#
# Executed when a link to another logic core is activated.
#   name  - The name of the link
#
proc activating_link_failed {name} {
  playMsg "Core" "activating_link_to";
  spellWord $name;
  playMsg "Core" "failed";
}


#
# Executed when a link to another logic core is deactivated
#   name  - The name of the link
#
proc deactivating_link {name} {
  playMsg "Core" "deactivating_link_to";
  spellWord $name;
}


#
# Executed when a link to another logic core shall beeing
# deactivated but the action failed for some reason
#   name  - The name of the link
#
proc deactivating_link_failed {name} {
  playMsg "Core" "deactivating_link_to";
  spellWord $name;
  playMsg "Core" "failed";
}


#
# Executed when a link to another logic core shall beeing
# deactivated but the action failed due to configuration
#   name  - The name of the link
#
proc deactivating_link_not_possible {name} {
  playMsg "Core" "deactivating_link_to";
  spellWord $name;
  playMsg "Core" "not_possible";
}


#
# Executed when trying to deactivate a link to another logic core but the
# link is not currently active.
#   name  - The name of the link
#
proc link_not_active {name} {
  playMsg "Core" "link_not_active_to";
  spellWord $name;
}


#
# Executed when trying to activate a link to another logic core but the
# link is already active.
#   name  - The name of the link
#
proc link_already_active {name} {
  playMsg "Core" "link_already_active_to";
  spellWord $name;
}


#
# Executed each time the transmitter is turned on or off
#   is_on - Set to 1 if the transmitter is on or 0 if it's off
#
proc transmit {is_on} {
  #puts "Turning the transmitter $is_on";
  variable prev_ident;
  variable need_ident;
  if {$is_on && ([clock seconds] - $prev_ident > 5)} {
    set need_ident 1;
  }
}


#
# Executed each time the squelch is opened or closed
#   rx_id   - The ID of the RX that the squelch opened/closed on
#   is_open - Set to 1 if the squelch is open or 0 if it's closed
#
proc squelch_open {rx_id is_open} {
  variable sql_rx_id;
  #puts "The squelch is $is_open on RX $rx_id";
  set sql_rx_id $rx_id;
}


#
# Executed when a DTMF digit has been received
#   digit     - The detected DTMF digit
#   duration  - The duration, in milliseconds, of the digit
#
# Return 1 to hide the digit from further processing in SvxLink or
# return 0 to make SvxLink continue processing as normal.
#
proc dtmf_digit_received {digit duration} {
  #puts "DTMF digit \"$digit\" detected with duration $duration ms";
  return 0;
}


#
# Executed when a DTMF command has been received
#   cmd - The command
#
# Return 1 to hide the command from further processing is SvxLink or
# return 0 to make SvxLink continue processing as normal.
#
proc dtmf_cmd_received {cmd} {
  #puts "DTMF command received: $cmd";
  return 0;
}


#
# Executed once every whole minute. Don't put any code here directly
# Create a new function and add it to the timer tick subscriber list
# by using the function addTimerTickSubscriber.
#
proc every_minute {} {
  variable timer_tick_subscribers;
  #puts [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"];
  foreach subscriber $timer_tick_subscribers {
    $subscriber;
  }
}


#
# Use this function to add a function to the list of functions that
# should be executed once every whole minute. This is not an event
# function but rather a management function.
#
proc addTimerTickSubscriber {func} {
  variable timer_tick_subscribers;
  lappend timer_tick_subscribers $func;
}


#
# Should be executed once every whole minute to check if it is time to
# identify. Not exactly an event function. This function handle the
# identification logic and call the send_short_ident or send_long_ident
# functions when it is time to identify.
#
proc checkPeriodicIdentify {} {
  variable prev_ident;
  variable short_ident_interval;
  variable long_ident_interval;
  variable min_time_between_ident;
  variable ident_only_after_tx;
  variable need_ident;

  if {$short_ident_interval == 0} {
    return;
  }

  set now [clock seconds];
  set hour [clock format $now -format "%k"];
  regexp {([1-5]?\d)$} [clock format $now -format "%M"] -> minute;

  set short_ident_now \
      	    [expr {($hour * 60 + $minute) % $short_ident_interval == 0}];
  set long_ident_now 0;
  if {$long_ident_interval != 0} {
    set long_ident_now \
      	    [expr {($hour * 60 + $minute) % $long_ident_interval == 0}];
  }

  if {$long_ident_now} {
    puts "Sending long identification...";
    send_long_ident $hour $minute;
    set prev_ident $now;
    set need_ident 0;
  } else {
    if {$now - $prev_ident < $min_time_between_ident} {
      return;
    }
    if {$ident_only_after_tx && !$need_ident} {
      return;
    }

    if {$short_ident_now} {
      puts "Sending short identification...";
      send_short_ident $hour $minute;
      set prev_ident $now;
      set need_ident 0;
    }
  }
}


#
# Executed when the QSO recorder is being activated
#
proc activating_qso_recorder {} {
  playMsg "Core" "activating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when the QSO recorder is being deactivated
#
proc deactivating_qso_recorder {} {
  playMsg "Core" "deactivating";
  playMsg "Core" "qso_recorder";
}


#
# Executed when trying to deactivate the QSO recorder even though it's
# not active
#
proc qso_recorder_not_active {} {
  playMsg "Core" "qso_recorder";
  playMsg "Core" "not_active";
}


#
# Executed when trying to activate the QSO recorder even though it's
# already active
#
proc qso_recorder_already_active {} {
  playMsg "Core" "qso_recorder";
  playMsg "Core" "already_active";
}


#
# Executed when the user is requesting a language change
#
proc set_language {lang_code} {
  puts "Setting language $lang_code (NOT IMPLEMENTED)";

}


#
# Executed when the user requests a list of available languages
#
proc list_languages {} {
  puts "Available languages: (NOT IMPLEMENTED)";

}


##############################################################################
#
# Main program
#
##############################################################################

if [info exists CFG_SHORT_IDENT_INTERVAL] {
  if {$CFG_SHORT_IDENT_INTERVAL > 0} {
    set short_ident_interval $CFG_SHORT_IDENT_INTERVAL;
  }
}

if [info exists CFG_LONG_IDENT_INTERVAL] {
  if {$CFG_LONG_IDENT_INTERVAL > 0} {
    set long_ident_interval $CFG_LONG_IDENT_INTERVAL;
    if {$short_ident_interval == 0} {
      set short_ident_interval $long_ident_interval;
    }
  }
}

if [info exists CFG_IDENT_ONLY_AFTER_TX] {
  if {$CFG_IDENT_ONLY_AFTER_TX > 0} {
    set ident_only_after_tx $CFG_IDENT_ONLY_AFTER_TX;
  }
}



# end of namespace
}

#
# This file has not been truncated
#
