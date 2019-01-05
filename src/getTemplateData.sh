#!/bin/bash

if [[ -z ${FSLDIR} ]]
then
	echo "need FSL for this script"
	exit 1
fi

################################################################################
# check command line
ANTSBREX_TEMPLATE_DIR=${1}
ANTSBREX_TEMPLATE_CHOICE=${2}

if [[ $# -ne 2 ]]
then
	echo "USEAGE: "
	echo "${0} directory template_choice [NKI,NKI10U,KIRBY,KIRBYMM,OASIS,IXI] "
	exit 1
fi

################################################################################
# check if variables

case ${ANTSBREX_TEMPLATE_CHOICE} in
	'NKI'|'NKI10U'|'KIRBY'|'KIRBYMM'|'OASIS'|'IXI')
		echo "template choice: ${ANTSBREX_TEMPLATE_CHOICE}"
		;;

	*)
		echo "invalid template choice: ${ANTSBREX_TEMPLATE_CHOICE}"
		exit 1
		;;
esac

if [[ ! -d ${ANTSBREX_TEMPLATE_DIR} ]]
then
	# if this directory does not exist, make the dir and prepar to dl some imgs
	mkdir -p ${ANTSBREX_TEMPLATE_DIR} || \
		{ echo "problem making dir. exiting" ; exit 1 ; }
fi

################################################################################
# get the variables we already need

finalT1w=${ANTSBREX_TEMPLATE_DIR}/antsBrEx_${ANTSBREX_TEMPLATE_CHOICE}_T1w_template.nii.gz
finalMask=${ANTSBREX_TEMPLATE_DIR}/antsBrEx_${ANTSBREX_TEMPLATE_CHOICE}_T1w_mask.nii.gz
finalExMask=${ANTSBREX_TEMPLATE_DIR}/antsBrEx_${ANTSBREX_TEMPLATE_CHOICE}_T1w_exmask.nii.gz

if [[ -e ${finalT1w} ]] && [[ -e ${finalMask} ]]
then
	echo "looks like final images already in place. will exit"
	echo "if you would like to rerun this script, plz move these images"
	exit 0
fi

# lets get the brain + masks with the cerebellum
fixMask='False'
case ${ANTSBREX_TEMPLATE_CHOICE} in
	'NKI')
		initT1w=T_template.nii.gz
		initMask=T_template_BrainCerebellumProbabilityMask.nii.gz
		initExMask=T_template_BrainCerebellumExtractionMask.nii.gz
		dlTarg='https://ndownloader.figshare.com/files/3133826'
		;;
	'NKI10U')
		initT1w=T_template0.nii.gz
		initMask=T_template0_BrainCerebellumProbabilityMask.nii.gz
		initExMask=T_template0_BrainCerebellumExtractionMask.nii.gz
		dlTarg='https://ndownloader.figshare.com/files/3133838'
		;;
	'KIRBY')
		initT1w=S_template3.nii.gz
		initMask=S_template3_BrainCerebellum.nii.gz
		initExMask=''
		fixMask='True'
		dlTarg='https://ndownloader.figshare.com/files/3133847'
		;;
	'KIRBYMM')
		initT1w=S_template3.nii.gz
		initMask=S_template_BrainCerebellumProbabilityMask.nii.gz
		initExMask=S_template_BrainCerebellumExtractionMask.nii.gz
		dlTarg='https://ndownloader.figshare.com/files/13298051'
		;;
	'OASIS')
		initT1w=T_template0.nii.gz
		initMask=T_template0_BrainCerebellumProbabilityMask.nii.gz
		initExMask=T_template0_BrainCerebellumExtractionMask.nii.gz
		dlTarg='https://ndownloader.figshare.com/files/3133832'
		;;
	'IXI')
		initT1w=T_template2.nii.gz
		initMask=T_template_BrainCerebellumProbabilityMask.nii.gz
		initExMask=T_template_BrainCerebellumExtractionMask.nii.gz
		dlTarg='https://ndownloader.figshare.com/files/3133820'
		;;
esac

################################################################################
# download the dir

# download
wget -O ${ANTSBREX_TEMPLATE_DIR}/tmpdl.zip ${dlTarg}

# and unzip
unzip -d ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir ${ANTSBREX_TEMPLATE_DIR}/tmpdl.zip
rm ${ANTSBREX_TEMPLATE_DIR}/tmpdl.zip

# move the contents down a dir level
mv ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/*/*nii.gz ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/

# now identify the images
if [[ ! -e ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initT1w} ]]
then
	echo "donwload T1w template does not exist. exiting"
	exit 1
fi

if [[ ! -e ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initMask} ]]
then
	echo "donwload mask template does not exist. exiting"
	exit 1
fi

if [[ ! -e ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initExMask} ]]
then
	echo "donwload ex mask template does not exist. exiting"
	exit 1
fi

################################################################################
# if the mask needs to be fixed

if [[ "${fixMask}" = 'True' ]]
then
	cmd="${FSLDIR}/bin/fslmaths \
			${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initMask} \
			-thr 0 -bin -dilM -dilM -ero -ero -s 1 \
			${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initMask} \
		"
	echo $cmd
	eval $cmd
fi

################################################################################
# fslreorient 2 std

cmd="${FSLDIR}/bin/fslreorient2std \
		${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initT1w} \
		${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/ref.nii.gz \
	"
echo $cmd
eval $cmd | tee ${ANTSBREX_TEMPLATE_DIR}/reor.xfm

cmd="${FSLDIR}/bin/fslreorient2std \
		${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initT1w}"
echo $cmd
eval $cmd | tee ${ANTSBREX_TEMPLATE_DIR}/reor.xfm

# apply the xfm to the images
for img in initT1w initMask initExMask
do
	# for the case where the initExMask does not exist
	if [[ ! -f ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${!img} ]]
	then
		continue
	fi

	cmd="${FSLDIR}/bin/flirt \
			-in ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${!img} \
			-ref ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/ref.nii.gz \
			-out ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${!img} \
			-applyxfm -init ${ANTSBREX_TEMPLATE_DIR}/reor.xfm \
		"
	echo $cmd
	eval $cmd

done

################################################################################
# move the final imgs

ls ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initT1w} && \
	mv ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initT1w} ${finalT1w}

ls ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initMask} && \
	mv ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initMask} ${finalMask}

[[ ! -z ${initExMask} ]] && \
	ls ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initExMask} && \
	mv ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/${initExMask} ${finalExMask}

# and remove the the tmpDir
ls -d ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/ && \
	rm -r ${ANTSBREX_TEMPLATE_DIR}/tmpdlDir/


