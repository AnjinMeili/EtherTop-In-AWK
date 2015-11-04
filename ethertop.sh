#! /usr/bin/ksh
# 
# Seeing how people here actually read source code, I suppose ill comment it
# and such. This script is actually written in nawk, but I have wrapped it
# with ksh to handle command line params and the like. Why AWK? Why NOT! 
# Client has requested that all work done on site be done using AWK, thus
# AWK was used.
#
# Basically, it filters the output of snoop into a single display and then
# updates the display showing the highest load sockets or hosts at the top
# of the display.  
#
# James Hutchinson, Sun MicroSystems 
#

Usage() {
	echo "
Usage: $0 [-h host] [-H] [-d device] [-f] [-m] [delay]
   Displays a screen showing traffic on the ethernet segment, in either 
   by host or by socket form.  Data is sorted so highest yield hosts are
   listed first. Data is only kept for DELAY period, unless [-m] is used. 

   Options 
   	   -h  Sample data for a single {host} only
   	   -H  Show data by host only, vs by socket
	   -d  use {device}, default is primary ethernet 
	   -f  Fast Ethernet Device (100mb/s)
	   -m  Keep data since run time. ***
   	delay  Process delay in seconds, default is 5

   *** WARNING: This option provides very useful data as the display is
       historic, rather then just per DELAY period, BUT it will soon eat
       your box alive. Best to combine with the hostmode [-H]. 
"
	exit $1
	}

# 
# Variables that we will be using in this script
#
NULL="/dev/null"
SNOOPFLAG=""
NAWKFLAG="socket"
DELAY=5
HOST="`/usr/bin/hostname`"
DEV="`netstat -i | nawk '$4~/^'$HOST'$/{print $1}'`"
DEVICEFLAG="-d $DEV"
PIPE="1000000"
MEMFLAG="clear"

#
# Check to see that we are ROOT
#
if [ `id | grep root >$NULL 2>&1 ; echo $?` -gt 0 ]
then
	echo "\n\007ERROR! You must be running as ROOT."
	Usage 1
fi

#
# Check to see that we are on a Solaris 2.x box
#
if [ `uname -r | grep "^5" >$NULL 2>&1 ; echo $?` -gt 0 ]
then
	echo "\n\007ERROR! Only runs on Solaris 2.x systems."
	Usage 1
fi

while getopts Hh:d:fFm opts 2>/dev/null
do
	case $opts in 
		 h) if [ `ypcat hosts | grep "$OPTARG\$" >$NULL 2>&1 ; \
				 echo $?` -gt 0 ]
		    then
		    	echo "\n\007ERROR! $OPTARG is not a valid host in NIS."
			Usage 1
		    fi
		    SNOOPFLAG="host $OPTARG"
		    ;;	
		 H) NAWKFLAG="host";;
		 d) if [ `netstat -i | grep "^$OPTARG" >$NULL 2>$1 ; \
				echo $?` -gt 0 ]
		    then
			echo "\n\007ERROR! $OPTARG is not a valid device."
			Usage 1
		    fi
		    DEV=$OPTARG
		    DEVICEFLAG="-d $OPTARG"
		    ;;
		 f) PIPE="10000000" ;;
		 F) PIPE="1000000000" ;;
		 m) MEMFLAG="save" ;;
		\?) Usage 1 ;;
	esac
done

shift `expr $OPTIND - 1`

if [ $# -gt 0 ]
then
	if [ $1 -gt 0 ]
	then
		DELAY=$1
	fi
fi

# 
# Need to fetch the rows and columns of the screen so we can build the output
# nice and pretty.
#		
stty -a | nawk '
	BEGIN{RS=";"}
	/rows/{r=$3;if(r<3)r=24}
	/columns/{c=$3;if(c<3)c=80}
	END{print r,c}
      ' | read ROWS COLS

export ROWS COLS DELAY NAWKFLAG HOST DEV

#
# Now we hope all is well, everything is setup, might as well get to work.
#
clear
snoop -S -t r -s 56 -D $DEVICEFLAG $SNOOPFLAG 2> /dev/null | nawk '
function sort(array, sary, scnt){
	for(i=2;i<=scnt;++i){
		for(j=i;array[sary[j-1]]>array[sary[j]];--j){
			temp=sary[j]; sary[j]=sary[j-1]; sary[j-1]=temp;
			}
		}
	return ;
	} 
function getcup( row, col ) {
	syscmd = sprintf("tput cup %s %s", row, col) ;
	syscmd | getline rstr ; close( syscmd ) ;
	return( rstr ) ;
	}
function cleararray( array ) {
	for( idx in array ) delete array[idx]
	}
BEGIN {
	for(i=1;i<=10;i++){
		spaces = sprintf("%s%s",spaces,"        ");
		dashs  = sprintf("%s%s",dashs ,"--------");
		graph  = sprintf("%s%s",graph ,"########");
		}
	MODE  = "'$NAWKFLAG'" ; DELAY = "'$DELAY'"+0 ;
	ROWS  = "'$ROWS'"+0   ; COLS  = "'$COLS'"+0 ;
	HOST  = "'$HOST'"     ; DEV   = "'$DEV'" ; 
	PIPE  = "'$PIPE'"+0   ; MEM   = "'$MEMFLAG'" ;
	printf ("        Host: %-20s Packets: %15s AvgUtil %%:\n",
		substr(HOST,1,20)," ");
	printf ("      Device: %-20s   Bytes: %15s   Dropped:\n",
		DEV," ");
	printf (" Period Util %%:       [%-50s]\n\n"," "); 
	pcup = getcup(0,44) ; bcup = getcup(1,44) ;
	uncup = getcup(2,16) ; ugcup = getcup(2,23) ;
	avcup = getcup(0,71) ; dcup = getcup(1,72) ;
	printf("%s%s",uncup,"00.00");	
	printf("%s",getcup(4,0));
	if(MODE=="socket"){
		printf("%-18s %-18s %-8s %-8s %8s %12s\n%s",
			"Orig Host","Dest Host","Type","Port",
			"Packets","Bytes",substr(dashs,1,77));
		}
	if(MODE=="host"){
		printf("%-30s %8s %14s\n%s","Hostname","Packets",
			"Bytes",substr(dashs,1,77));
		}
	for(i=1;i<=ROWS;i++){ row[i]=getcup(i+5,0) ; }
	}
	
{ 
	orig = $2 ; dest = $4 ; size = $8 ; type = $9 ; ppackets = 0 ;
	time = int($1+0) ; drops = int($6+0) ; pdrops = 0 ;
	tcnt = split($11,tary,"=") ;
	if ( tcnt == 1 ) port = $11 ;
	if ( tcnt == 2 ) port = tary[2] ;
	if(MODE=="socket"){
		tpkts[orig,dest,type,port]++ ;
		bytes[orig,dest,type,port]=bytes[orig,dest,type,port]+size ;
		}
	if(MODE=="host"){
		tpkts[orig]++ ; bytes[orig]=bytes[orig]+size ;
		tpkts[dest]++ ; bytes[dest]=bytes[dest]+size ;
		}
	totalbytes=totalbytes+size ;
	ppackets++ ; tdrops = tdrops + drops ;
	pdrops = pdrops + drops ;
	if( (time/DELAY) == int(time/DELAY) && time > otime ) {
		otime = time ; hcnt = 0 ; tcnt = 0 ;
		for(idx in bytes) { ++hcnt ; hary[hcnt]=idx ; }
		sort(bytes,hary,hcnt);
		printf("%s%s",pcup,NR);
		printf("%s%s",bcup,totalbytes);
		ptbytes = totalbytes-otbytes ;
		otbytes = totalbytes ;
		dropavrg = ptbytes / ppackets ;
		dropbytes = dropavrg * pdrops ;
		ptbytes = (ptbytes)/DELAY ;
		util = (ptbytes*100)/PIPE ;
		tutil = ((totalbytes/time)*100)/PIPE ;
		printf("%s%05.2f",avcup,tutil);
		printf("%s%s",dcup,tdrops);
		printf("%s%05.2f",uncup,util);
		printf("%s%s%s%s",ugcup,substr(spaces,1,50),ugcup,
			substr(graph,1,int(util/2)+1));
		for(i=hcnt;tcnt<(ROWS-7);i--) {
			tcnt++;
			if(MODE=="socket"){
				split(hary[i],tary,SUBSEP);
				torig=tary[1] ; tdest=tary[2] ; 
				ttype=tary[3] ; tport=tary[4] ;
				printf("%s%s%s%-18s %-18s %-8s %-8s %8s %12s",
					row[tcnt],spaces,row[tcnt],
					substr(tary[1],1,17),
					substr(tary[2],1,17),
					substr(tary[3],1,8),
					substr(tary[4],1,8),
					tpkts[hary[i]],bytes[hary[i]]);
				}
			if(MODE=="host"){
				host=hary[i] ;
				printf("%s%s%s%-30s %8s %20s",row[tcnt],
					spaces,row[tcnt],
					substr(host,1,29),tpkts[host],
					bytes[host]);
				}
			}
		if( MEM == "clear" ) {
			cleararray(hary) ;
			cleararray(tpkts) ;
			cleararray(bytes) ;
			}
		}
	}'
