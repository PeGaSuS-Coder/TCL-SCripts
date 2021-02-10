#####
# Nickname/Uhost tracker script (SimosNap)
# Egghelp version, donations to slennox are welcomed. :P
# Minor tweaks by PeGaSuS
#####

#####
# We need at least TCL >=8.5 due to the -nocase in lsearch
# Thanks mezen for the reminder and for the split_list procedure
#####
package require Tcl 8.5

##########
# should duplicate nicknames be allowed?
##########
# 0 = no, 1 and above = yes
##########
set dupes 0

##########
# Map channels to send the message to a backchan
##########
set channelmap {
	"#amicizia" "#camelot"
	"#lolchat" "#lolstaff"
	"#allnitecafe" "#allnitecafe-ops"
}

##########
# Binds
##########
bind nick - * nick_nickchange
bind join - * join_onjoin
##########
# End of binds
##########

##########
# Channel flag
##########
setudef flag nicktrack

##########
# Procs
##########

##########
# Splitting lists
##########
proc split_list {list n} {
	set lines {}
	set line {}
	set m [llength $list]
	for {set i 0} {$i < $m} {incr i} {
		set item [lindex $list $i]
		lappend line $item
		if {[string length $line] > $n || $i == [expr {$m-1}]} {
			# split here
			lappend lines $line
			set line {}
		}
	}
	return $lines
}

##########
# check for nick changes
##########
proc nick_nickchange {nick uhost hand chan newnick} {
	if {![channel get $chan "nicktrack"]} {
		return 0
	}
	join_onjoin $newnick $uhost $hand $chan
	return 0
}

##########
# check for joins
##########
proc join_onjoin {nick uhost hand chan} {
	global botnick dupes channelmap
	if {![channel get $chan "nicktrack"]} {  return 0  }

	# keep everything lowercase for simplicity.
	set ch [strlwr $chan]
	set filename "[string trim "$ch" #]_nicklist.txt"
	#set uhost [strlwr [maskhost [getchanhost $nick $chan] 2]]; # This leaded to erratic bahaviour in some clients using shared services
	set uhost [strlwr $uhost]
	# read the file
	if {![file exists $filename]} {
		set file [open $filename "w"]
		close $file
	}

	set file [open $filename "r"]
	set text [split [read $file] \n]
	close $file
	# locate a duplicate host
	set found [lsearch -glob $text "*<$uhost"]
	if {$found < 0} {
		# host isn't found so let's append the nick and host to our file
		set file [open $filename "a"]
		puts $file "$nick<$uhost"
		close $file
	} else {
		# the host exists, so set our list of nicks for that host
		set nicks [lindex [split [lindex $text $found] "<"] 0]
		# is the nick already known for that host?
		set nlist [split $nicks ","]
		if {[set pos [lsearch -nocase $nlist $nick]] != -1} { set nlist [lreplace $nlist $pos $pos] }

		# MAKE SURE TO READ THE COMMENTS BELOW

		if {[string length [join $nlist]]} {
			if {$ch in [dict keys $channelmap]} {
				set bkc [dict get $channelmap $ch]
				if {[regexp c [getchanmode $bkc]]} {
					foreach line [split_list $nlist 150] {
						putserv "PRIVMSG $bkc :\[$chan\] $nick ha usato: [join $line " • "]"
					}
				} else {
					foreach line [split_list $nlist 150] {
						putserv "PRIVMSG $bkc :\00302\[$chan\]\003 \002$nick\002 ha usato: \00304[join $line " • "]"
					}
				}
			} elseif {[isop $botnick $chan]} {
				if {[regexp c [getchanmode $ch]]} {
					foreach line [split_list $nlist 150] {
						putserv "NOTICE @$ch :$nick ha usato: [join $line " • "]"
					}
				} else {
					foreach line [split_list $nlist 150] {
						putserv "NOTICE @$ch :\002$nick\002 ha usato: \00304[join $line " • "]"
					}
				}
			} else {
				return 0
			}
		}

		set known [lsearch -exact -nocase [split $nicks ","] $nick]
		if {($known != -1) && ($dupes < 1)} {
			# if the nick is known return
			return
		} else {
			# otherwise add the nick to the nicks for that host
			set text [lreplace $text $found $found "$nicks,$nick<$uhost"]
		}
		# now lets write the new list to the file
		set file [open $filename "w"]
		foreach line $text {
			if {[string length $line]} {
				puts $file "$line"
			}
		}
		close $file
	}
	return 0
}

putlog "Nickname/Uhost tracker enabled."