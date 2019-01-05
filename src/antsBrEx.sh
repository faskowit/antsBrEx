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
        -i          inputImage --> input freesurfer directory
        -o          outputDir ---> output directory, will also write temporary 
                        files here 
        -d (opt)    refBrainDir -> directory where reference brains could exist
        -t (opt)    refBrain ----> NKI, NKIU10, OASIS, IXI, KIRBY, KIRBYMM
helpusagetext
}

usage() 
{
cat <<usagetext
USAGE: ${0} 
        -i          inputImage 
        -o          outputDir
        -d 			refBrainDir
        -t (opt)    refBrain  
usagetext
}

main()
{

	start=`date +%s`

	############################################################################
	############################################################################
	# args

	# Check the number of arguments. If none are passed, print help and exit.
	if [[ "$#" -eq 0 ]]; then
		usage >&2 
		exit 1
	fi

	inputImg=''
	outputDir=''
	templateChoice=''
	templateDir=''

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
			d)  templateDir=$OPTARG
				;;
			t)
				templateChoice=$OPTARG
				;;
			h) 
				help_usage &>2
	            exit 1
	      		;;
			?) # getopts issues an error message
				usage &>2
	            exit 1
	      		;;
	     esac
	done

	shift "$((OPTIND-1))" # Shift off the options and optional

	############################################################################
	############################################################################
	# check args

	exeDir=$(dirname "$(readlink -f "$0")")/

	if [[ ! -f ${inputImg} ]]
	then
		echo "image does not exist"
		exit 1
	fi

	mkdir -p ${outputDir} || { echo "cant make dir" ; exit 1 ; }

	if [[ -z ${templateDir} ]]
	then
		templateDir=${outputDir}/template/
		tempTemplate='True'
	fi

	if [[ -z ${templateChoice} ]]
	then
		templateChoice=NKI
	fi

	> ${outputDir}/antsBrExNotes.txt
	OUT=${outputDir}/antsBrExNotes.txt

	############################################################################
	############################################################################
	# check template, download if necessary

	${exeDir}/getTemplateData.sh ${templateDir} ${templateChoice}

	# read exist arg
	exitArg=$?
	if [[ ${exitArg} -ne 0 ]]
	then
		str="problem with getting the template. existing"
		echo $str
		log $str >> $OUT
		exit 1
	fi

	targTemplate=${templateDir}/antsBrEx_${templateChoice}_T1w_template.nii.gz
	targMask=${templateDir}/antsBrEx_${templateChoice}_T1w_mask.nii.gz
	targExMask=${templateDir}/antsBrEx_${templateChoice}_T1w_exmask.nii.gz

	############################################################################
	############################################################################
	# first, lets initialize with FSL linear xfm

	if [[ ! -f ${outputDir}/img_2_template.nii.gz ]]
	then

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

	fi

	############################################################################
	############################################################################
	# run the antsBrainExtraction

	#antsBrainExtraction -d imageDimension
    #          -a anatomicalImage
    #          -e brainExtractionTemplate
    #          -m brainExtractionProbabilityMask
    #          <OPT_ARGS>
    #          -o outputPrefix

    cmd="${exeDir}/external/antsBrainExtraction.sh \
    		-d 3 \
    		-a ${outputDir}/img_2_template.nii.gz \
    		-e ${targTemplate} \
    		-m ${targMask} \
    		-o ${outputDir}/antsBEtmp/ \
    		-q 1 \
    	"
    if [[ -f ${targExMask} ]]
    then
    	cmd="$cmd -f ${targExMask}"
    fi

	echo $cmd
    log $cmd >> $OUT
	eval $cmd

	############################################################################
	############################################################################
	# put the mask back into native space

	antsOutMask=${outputDir}/antsBEtmp/BrainExtractionMask.nii.gz

	if [[ ! -f ${antsOutMask} ]]
	then
		echo "ants brain extraction did not work, problem"
		exit 1
	fi

	# apply the inverse xfm
	cmd="${FSLDIR}/bin/flirt \
			-in ${antsOutMask} \
			-ref ${inputImg} \
			-out ${outputDir}/antsBrEx_mask.nii.gz \
			-applyxfm -init ${outputDir}/template_2_img.xfm \
			-interp nearestneighbour \
		"
	echo $cmd
    log $cmd >> $OUT
	eval $cmd

	# if that worked, we can cleanup
	if [[ -f  ${outputDir}/antsBrEx_mask.nii.gz ]]
	then
		rm -r ${outputDir}/antsBEtmp/
		rm ${outputDir}/img_2_template.nii.gz

		if [[ "${tempTemplate}" = "True" ]]
		then 
			rm -r ${templateDir}
		fi
	fi

	############################################################################
	############################################################################
	# record how long that all took

	end=`date +%s`
	runtime=$((end-start))
	echo "runtime: $runtime"
	log "runtime: $runtime" >> $OUT 2>/dev/null

} # main

# run main
main "$@"

