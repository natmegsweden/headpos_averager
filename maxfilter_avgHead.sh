#!/bin/bash

## Script for automatic maxfilter processing where movement correction is done by shifting to
## the average headposition, calculated from continous head position estimation in MaxFilter,
## across the session.
##
## Procedure:
## 1) Run SSS movement estimation
## 2) Run Python or matlab scripts to get average position from output
## 3) Save in -trans file or update in SSS file
## 4) Re-run maxfilter with correct settings (tSSS, movecomp, etc.) and transform to avg. headpos.
##
## Mikkel C. Vinding (2017) and Lau M. Andersen (2016-2017)
##
## No warraty guarateed. This is a wrapper for calling Neuromag MaxFilter within the NatMEG (www.natmeg.se) infrastructure. Neuromag MaxFilter is 
## a comercial software. For reference read the MaxFilter Manual.
##
## For question contact: mikkel.vinding@ki.se

###########################################################################################################################################################################
# TO DO:
# - Run SSS movement estimation
# - Run Python or matlab scripts to get average position from output [Not present on this PC yet - 2017-12-21]
# - - Save in -trans file or update in SSS file
# - re-run maxfilter with correct settings (tSSS, movecomp, etc.) and transform to avg. headpos.
#
# - Read in more than one file (e.g. for recordings over 2GB)
# - option to use mean or median to estimate headpos
# - option to use continous or initial head pos
#

#############################################################################################################################################################################################################################################################
## These are the ONLY parameters you should change (as according to your wishes). For more info we recommend reading the MaxFilter Manual.
## NB! Do not use spaces between "equal to" signs.
#############################################################################################################################################################################################################################################################

## STEP 1: On which conditions should average headposition be done (consistent naming is mandatory!)?
project=working_memory    	# The name of your project in /neuro/data/sinuhe
trans_conditions=( 'rest_eo' 'rest_ec' 'tap' 'pam' 'singlefinger' )
trans_option=continous 		# continous/initial, how to estimate average head position: From INITIAL head fit across files, or from CONTINOUS head position estimation within (and across) files, e.g. split files? [NOT YET IMPLEMENTED]
trans_type=median 		# mean/median, method to estimate "average" head position. [NOT YET IMPLEMENTED]
keep_headposfiles=yes 		# yes/no, would you like to keep the files used to calculate the avergae head position?

## STEP 2: Put the names of your empty room files (files in this array won't have "movecomp" applied) (no commas between files and leave spaces between first and last brackets)
empty_room_files=( 'empty_room1_before.fif' 'empty_room1_after.fif' 'empty_room2_before.fif' 'empty_room2_after.fif' )

## STEP 3: Select MaxFilter options.
autobad=on 			# Options: on/off
tsss_default=on 		# on/off (if off does Signal Space Separation, if on does temporal Signal Space Separation)
correlation=0.98 		# tSSS correlation rejection limit (default is 0.98)
movecomp_default=on # on/off

#############################################################################################################################################################################################################################################################
## Default initial settings for headposition estimation (only change if you are certain that is what you want to do)
#############################################################################################################################################################################################################################################################

#trans_option='on' # on/off NB! See below
#transformation_to=default ## default is "default", but you can supply your own file 
calc_avg_headpos='yes' #yes/no
#headpos=off # on/off ## if "on", no movement compensation (movecomp is automatically turned off, even if specified "on")
force=off # on/off, "forces" the command to ignore warnings and errors and OVERWRITES if a file already exists with that name
downsampling=off # on/off, downsamples the data with the factor below
downsampling_factor=4 # must be an INTEGER greater than 1, if "downsampling = on". If "downsampling = off", this argument is ignored
sss_files=( 'only_apply_sss_to_this_file.fif' ) ## put the names of files you only want SSS on (can be used if want SSS on a subset of files, but tSSS on the rest)
apply_linefreq=off ## on/off
linefreq_Hz=50 ## set your own line freq filtering (ignored if above is off),
cal=/neuro/databases/sss/sss_cal.dat
ctc=/neuro/databases/ctc/ct_sparse.fif

#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################
## DON'T CHANGE ANYTHING BELOW HERE (UNLESS YOU REALLY KNOW WHAT YOU ARE DOING!)
#############################################################################################################################################################################################################################################################
#############################################################################################################################################################################################################################################################

data_path=/neuro/data/sinuhe
trans_path=/trans_files
cd $data_path
cd $project/MEG

#############################################################################################################################################################################################################################################################
## Abort if project folder doesn't exist and check if tran and pos folders exist
#############################################################################################################################################################################################################################################################

if [ $? -ne 0 ]  
then
	echo "specified project folder doesn't exist (change project variable)"
	exit 1
fi


#############################################################################################################################################################################################################################################################
## Setup the varios MaxFilter option for the real run
#############################################################################################################################################################################################################################################################

#############################################################################################################################################################################################################################################################
## create set_movecomp function (sets movecomp according to wishes above and abort if set incorrectly, this is a function such that it can be changed throughout the script if empty_room files are found)
set_movecomp () 
{

	if [ "$1" = 'on' ]
	then
		movecomp=-movecomp
		movecomp_string=_mc
	elif [ "$1" = "off" ]
	then	
		movecomp=
		movecomp_string=
	else echo 'faulty "movecomp" setting (must be on or off)'; exit 1
	fi

}

#############################################################################################################################################################################################################################################################
## create set_tsss function
set_tsss ()
{
	if [ "$1" = 'on' ]
	then
		tsss=-st
		tsss_string=_tsss
	elif [ "$1" = "off" ]
	then
		tsss=
		tsss_string=_sss
	else echo 'faulty "tsss" setting (must be on or off)'; exit 1
	fi
}

#############################################################################################################################################################################################################################################################
## set linefreq according to wishes above and abort if set incorrectly
if [ "$apply_linefreq" = 'on' ]
then
	linefreq="-linefreq $linefreq_Hz"
	linefreq_string=_linefreq_$linefreq_Hz
elif [ "$apply_linefreq" = 'off' ]
then
	linefreq=
	linefreq_string=
else echo 'faulty "apply_linefreq" setting (must be on or off)'; exit 1;
fi
	

#############################################################################################################################################################################################################################################################
## set trans according to wishes above and abort if set incorrectly [REMOVE?]
#############################################################################################################################################################################################################################################################

#if [ "$trans_option" = 'on' ]
#then
#	trans="-trans ${transformation_to}"
#	trans_string=_trans_${transformation_to}
#
#elif [ "$trans_option" = "off" ]
#then
#	trans=
#	trans_string=
#else echo 'faulty "trans_option" setting (must be on or off)'; exit 1;
#fi

#############################################################################################################################################################################################################################################################
## set headpos (head position)  according to wishes above and abort if set incorrectly [REMOVE?]
#############################################################################################################################################################################################################################################################

#if [ "$headpos" = 'on' ]
#then
#	headpos=-headpos
#	headpos_string=_quat
#elif [ "$headpos" = "off" ]
#then
#	headpos=
#	headpos_string=
#else echo 'faulty "headpos" setting (must be on or off)'; exit 1;
#fi

#############################################################################################################################################################################################################################################################
## set <force> parameter according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$force" = 'on' ]
then
	force="-force"
elif [ "$force" = "off" ]
then
	force=
else echo 'faulty "force" setting (must be on or off)'; exit 1;
fi

#############################################################################################################################################################################################################################################################
## set <downloading> parameter according to wishes above and abort if set incorrectly
#############################################################################################################################################################################################################################################################

if [ "$downsampling" = 'on' ]
then
	if [ $downsampling_factor -gt 1 ]
	then
		ds="-ds "$downsampling_factor
		ds_string=_ds_$downsampling_factor
	else echo "downsampling factor must be an INTEGER greater than 1";
	fi
	
	
elif [ "$downsampling" = 'off' ]
then
	ds=
	ds_string=
else echo 'faulty "downsampling" setting (must be on or off)'; exit 1;
fi


############################################################################################################################################################################################################################################################
## find all subject folders in project
############################################################################################################################################################################################################################################################

subjects_and_dates=( $(find . -maxdepth 2 -mindepth 2 -type d -exec echo {} \;) )

############################################################################################################################################################################################################################################################
## loop over subject folders
############################################################################################################################################################################################################################################################

for subject_and_date in "${subjects_and_dates[@]}"
do
	
	cd $data_path/$project/MEG/$subject_and_date/

	# create log file directory if it doesn't already exist
	if [ ! -d log ]; then
		echo "Creating folder for MaxFilter logfiles"
		mkdir log 		#
	fi

	## create file directory for quad files if it doesn't already exist
	if [ ! -d quat_files ]; then
		echo 'quat folder does not exist. Will make one for $subject_and_date'
		mkdir quat_files 		
		mkdir headpos
	else echo "a dir"
	fi

####################################################################################################################################################################################################################################################
	## Get the average head position	####################################################################################################################################################################################################################################################

	if [ "$trans_option=" = 'initial' ]; then
		echo "Will use the average of initial head position fit"
		for condition in ${trans_conditions[*]}
		do
#			echo $condition
			source /home/natmeg/data_scripts/avg_headpos/avgHeadPos.sh $condition ### TEST IF MULTIPLE FILES ARE SUPPORTET. RENAME FILES
		done
	elif [ "$trans_option=" = 'continous' ];
		echo "Will use the average of continous head position"
		echo "Now running MaxFilter to get continous head position..."


		for prefx in ${trans_conditions[*]}
		do
			fname=$( find ./quat_files -type f -print | grep $prefix)
			echo $fname

		done

	fi

	exit 1
		
		for condition in ${trans_conditions[*]}
		do

			# Run maxfilter
#			/neuro/bin/util/maxfilter -f ${fname} -o ./quat_files/$quat_fname -headpos -hp ./headpos/$pos_fname 

#			source /home/natmeg/data_scripts/avg_headpos/headpos_avg.sh $condition




	fi

	####################################################################################################################################################################################################################################################
	## loop over files in subject folders	####################################################################################################################################################################################################################################################
	



	for filename in `ls -p | grep -v / `;
	do
		echo ----------------------------------------------------------------------
		echo "Now running initiat MaxFilter process to get continous head position"
		echo ----------------------------------------------------------------------

		for prefx in ${trans_conditions[*]}
		do
			fname=$( find ./quat_files -type f -print | grep $prefix)
			echo $fname
		############################################################################################################################################################################################################################################
		## Run initial maxfilter to estimate continous head position		############################################################################################################################################################################################################################################
		length=${#filename}-4  ## the indices that we want from $file (everything except ".fif")
		pos_fname=${filename:0:$length}_headpos.pos 	# the name of the text output file with movement quaternions (not used for anything)
		quat_fname=${filename:0:$length}_quat.fif 	# the name of the quat output file

		#This will make output files for all files including spilt files. This has to be taken into account.
		/neuro/bin/util/maxfilter -f ${fname} -o ./quat_files/$quat_fname -headpos -hp ./headpos/$pos_fname 


		for condition in ${trans_conditions[*]}
		do
#			echo $condition
			source /home/natmeg/data_scripts/avg_headpos/avgHeadMove.sh $condition  
			# Here we need to know if it need to get all filenames or if MNE can handle that! 
		done
		fi

		############################################################################################################################################################################################################################################
		## check whether file is in the empty_room_files array and change movement compensation to off is so, otherwise use the movecomp_default setting 	############################################################################################################################################################################################################################################
		
		if [ $movecomp_default = 'on' ]
		then
			set_movecomp 'on'
		else set_movecomp 'off'
		fi
		
		for empty_room_file in ${empty_room_files[*]}
		do
			if [ -n $filename ]
			then	if [ $empty_room_file = $filename ]
				then
					set_movecomp 'off'
				fi
			fi
		done
		
		if [ -n "$headpos" ]
			then 	if [ $headpos = "-headpos" ]
				then
				set_movecomp 'off'
				fi
		fi

		############################################################################################################################################################################################################################################
		## check whether file is in the average head pos array and change trans argument
############################################################################################################################################################################################################################################
		if [ "$trans_option" = 'on' ]
		then
			for prefix in ${trans_conditions[*]}
			do
#				echo $prefix
				if [[ $filename == $prefix* ]]
				then
#					echo 'found $prefix'
#					echo $filename
					trans_fname=$( find ./quat -type f -print | grep $prefix)  # What will the actual filename be [!?!]
#					echo $trans_fname
					trans="-trans ${trans_fname}"
					trans_string=_trans
					break
				else
					trans=
					trans_string=					
				fi
			done
		elif [ "$trans_option" = "off" ]
		then
			trans=
			trans_string=
		else echo 'faulty "trans" setting (must be on or off)'; echo $trans_option #exit 1;
		fi

		echo 'Trans is:'
		echo $trans

		echo 'trans sting is:'
		echo $trans_string
		############################################################################################################################################################################################################################################
		## check whether file is in the sss_files array and change tsss to off is so, otherwise use the tsss_default setting 		############################################################################################################################################################################################################################################
		
		if [ $tsss_default = 'on' ]
		then
			set_tsss 'on'
		else set_tsss 'off'
		fi
		
		for sss_file in $sss_files
		do
			if [ -n $sss_file ]
			then	if [ $sss_file = $filename ]
				then
					set_tsss 'off'
				fi
			fi
		done
		############################################################################################################################################################################################################################################
		## output arguments 		############################################################################################################################################################################################################################################

		output_file=${filename:0:$length}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}${tsss_string}.fif 
		echo $output_file
		############################################################################################################################################################################################################################################
		## the actual maxfilter commands ############################################################################################################################################################################################################
		
		/neuro/bin/util/maxfilter -f ${filename} -o ${output_file} $force $tsss $ds -corr $correlation $movecomp $trans -autobad $autobad -cal $cal -ctc $ctc -v $headpos $linefreq | tee -a ./log/${filename:0:$length}${tsss_string}${movecomp_string}${trans_string}${headpos_string}${linefreq_string}${ds_string}.log
#		echo "Would run MaxF here!"
	done
	####################################################################################################################################################################################################################################################
	## file loop ends ##################################################################################################################################################################################################################################

done

############################################################################################################################################################################################################################################################
## subjects loop ends ######################################################################################################################################################################################################################################
############################################################################################################################################################################################################################################################