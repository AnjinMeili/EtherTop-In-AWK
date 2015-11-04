# EtherTop-In-AWK
Shell + AWK based filter to sort active ethernet traffic on a host into a top like display from highest consumer.

Shell script wrapper around an AWK script that polls netstat, then shows the connections in period in highest to least use.  

Wrote this while working at Sun in 1996.  I believe it the first construct of the function, and is given for its education value over its function.  The curses method is quite simple, and dynamic to the TERM value.  Using associations to preload tput control strings as a curses interface.  

The data elements are tracked thru a quad set of associations.  NAWK, a newer AIX AWK, or GAWK are requirements.  But the speed of count, ordering, sorting and display shows just how efficient 

James Hutchinson
