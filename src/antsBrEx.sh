#!/bin/bash

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab
Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

log() 
{
    local msg="$*"
    local dateTime=`date`
    echo "# "$dateTime "-" $log_toolName "-" "$msg"
    echo "$msg"
    echo 
}

help_usage() 
{
cat <<helpusagetext
USAGE: ${0} 
        -d          inputFSDir --> input freesurfer directory
        -o          outputDir ---> output directory, will also write temporary 
                        files here 
        -r (opt)    refBrain ----> file to be used as reference transforming 
                        aparc+aseg.mgz out of FS conformed space (default=rawavg) 
        -n (opt)    numThread ---> number of parallel processes to use when doing
                        the label transfer (default=4)
helpusagetext
}

usage() 
{
cat <<usagetext
USAGE: ${0} 
        -d          inputFSDir 
        -o          outputDir 
        -r (opt)    refBrain 
        -n (opt)    numThread 
usagetext
}

main()
{

	start=`date +%s`

	############################################################################
	############################################################################
	# args

	# Check the number of arguments. If none are passed, print help and exit.
	NUMARGS=$#
	if [ $NUMARGS -lt 2 ]; then
		echo "Not enough args"
		usage &>2 
		exit 1
	fi

	# read in args
	while getopts "a:b:c:d:e:f:g:hi:j:k:l:m:n:o:p:q:s:r:t:u:v:w:x:y:z:" OPTION
	do
	     case $OPTION in
			i)
				inputImg=$OPTARG
				;;
			o)
				outputDir=$OPTARG
				;;
			t)
				templateChoice=$OPTARG
				;;
			h) 
				help_usage >&2
	            exit 1
	      		;;
			?) # getopts issues an error message
				usage >&2
	            exit 1
	      		;;
	     esac
	done

	shift "$((OPTIND-1))" # Shift off the options and optional

	############################################################################
	############################################################################
	# check args


	touch ${outputDir}/antsBrExNotes.txt

	############################################################################
	############################################################################
	# check template, download if necessary

	${PWD}/getTemplateData.sh ${templateChoice}

	# read exist arg
	exitArg=$?
	if [[ ${exitArg} -ne 0 ]]
	then
		str="problem with getting the template. existing"
		echo $str
		log $str >> $OUT
		exit 1
	else
		targTemplate=${outputDir}/targ.nii.gz
	fi

	############################################################################
	############################################################################
	# first, lets initialize with FSL linear xfm

	#### in order to initialize 
	cmd="${FSLDIR}/bin/flirt \
		    -in ${inputImg} \
		    -ref ${targTemplate} \
		    -omat ${outputDir}/img_2_template.xfm \
		    -out ${outputDir}/img_2_template.nii.gz \
		    -dof 12 \
		    -interp spline \
	        -searchrx -60 60 \
		    -searchry -60 60 \
		    -searchrz -60 60 \
	    "
	echo $cmd
    log $cmd >> $OUT
	eval $cmd

	cmd="${FSLDIR}/bin/convert_xfm \
		    -omat ${outputDir}/template_2_img.xfm \
		    -inverse ${outputDir}/img_2_template.xfm \
	    "
	echo $cmd
    log $cmd >> $OUT
	eval $cmd

	############################################################################
	############################################################################
	# run the antsBrainExtraction

	#antsBrainExtraction -d imageDimension
    #          -a anatomicalImage
    #          -e brainExtractionTemplate
    #          -m brainExtractionProbabilityMask
    #          <OPT_ARGS>
    #          -o outputPrefix

    cmd="${PWD}/external/antsBrainExtraction.sh \
    		-d 3 \
    		-a ${outputDir}/img_2_template.nii.gz \
    		-e \
    		-m \
    		-o ${outDir}/antBE \
    	"
    log $cmd >> $OUT

    

	############################################################################
	############################################################################
	# put the mask back into native space



	############################################################################
	############################################################################
	# record how long that all took

	end=`date +%s`
	runtime=$((end-start))
	echo "runtime: $runtime"
	log "runtime: $runtime" >> $OUT 2>/dev/null

} # main

# run main
main