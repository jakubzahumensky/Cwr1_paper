setBatchMode(true);
test = 0;
//test = 1;
subset_default = "";
//subset_default = "AmB_20uM,2";


////////////////////////////////////////////////////////////////////////////////
// Abbreviations used:
// PM - plasma membrane
// cyt - cytosol
// CV - coefficient of variance
// BC - background; when appended to a variable, means "background corrected"
////////////////////////////////////////////////////////////////////////////////

version = 13.5;
extension_list = newArray("czi", "oif", "lif", "tif", "vsi"); //only files with these extensions will be processed; if your filetype is not in the group, simply add it
image_types = newArray("transversal", "tangential"); //there are either tranversal (going through the middle) or tangential (showing the surface) microscopy images. Z-stack projections are a special case of the latter.
boolean = newArray("yes","no");

//initial values of variables that change within functions
var temp_files_count = 0;
var continue_analysis = 0;
var count = 0;
var counter = 1;
var proc_files_number = 0;
//var temp_file = "analysis results";
var title = "";
var roiDir = "";
var patchesDir = "";
var pixelHeight = 0;
var CHANNEL = newArray(1);
var ch = 1;
var proc_files = "";
var pixelWidth = 0;
var Image_Area = 0;
var PM_base_BC = 0;
var bit_depth = 0;
var PM_length = 0;

CV_threshold = 0.3; //CV for discrimination of cells without patches
PBody_threshold = 5; //intensity fol threshold for the identification of abnormally bright puncta at/near the plasma membrane (PM) - can correspond to P-bodies, stress granules, mitochondria in close contact with the PM
cell_size_min = 5; //by default, cells with area smaller than 5 um^2 are excluded from the analysis. Can be changed in the dialog window below when analysis is run
SaveMasks = false;
//ScaleFactor = 2/3; //scaling factor for circular ROI creation inside segmentation masks of tangential cell sections
Gauss_Sigma = 1; //Smoothing factor (Gauss)
PatchProminence = 1.666; //Patch prominence threshold (for transversal images) - set semi-empirically

//The following text is displayed when the "Help" button is pressed in the Dialog window below
html0 = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b><br>"
	+"If used, only images with filenames containing specified <i>string</i> (i.e., group of characters and/or numbers) will be processes. "
	+"This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory (and its subdirectories).<br>"
	+"<br>"
	+"<b>Channel</b><br>"
	+"Specify image channel to be used for processing. Macro needs to be run separately for individual channels.<br>"
	+"<br>"
	+"<b>Naming scheme</b><br>"
	+"Specify how your files are named (without extension). Results are reported in a comma-separated table, with the parameters specified here used as column headers. "
	+"The default \"<i>strain,medium,time,condition,frame</i>\" creates 5 columns, with titles \"strains\", \"medium\" etc. "
	+"Using a consistent naming scheme accross your data enables automated downstream data processing of data.<br>"
	+"<br>"
	+"<b>Experiment code scheme</b><br>"
	+"Specify how your experiments are coded. The macro assumes a folder structure of <i>\".../experimental_code/biological_replicate_date/data<sup>*</sup>/\"</i>. See protocol for details.<br>"
	+"<sup>*</sup> - or <i>\"data-caps\"</i> for tangential images. <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Min and max cell size</b><br>"
	+"Specify lower (<i>min</i>) and upper (<i>max</i>) limit for cell area (in &micro;m<sup>2</sup>; as appears in the microscopy images). "
	+"Only cells within this range will be included in the analysis. The default lower limit is set to 5 &micro;m<sup>2</sup>, which corresponds to a small bud of a haploid yeast. "
	+"<i>The user is advised to measure a handful of cells before adjusting these limits. If in doubt, set limits 0-Infinity and filter the results table.</i><br>"
	+"<br>"
	+"<b>Coefficient of variance (CV) threshold</b><br>"
	+"Cells whose intensity coefficient of variance (standard deviation/mean) is below the specified value will be excluded from the analysis. Can be used for automatic removal of dead cells, "
	+"but <i>a priori</i> knowledge about the system is required. Filtering by CV can be performed <i>ex post</i> in the results table.<br>"
	+"<br>"
	+"<b>Deconvolved</b><br>"
	+"Select if your images have been deconvolved. If used, no Gaussian smoothing is applied to images before quantification of patches in the plasma membrane. "
	+"In addition, prominence of 1.333 is used instead of 1.666 used for confocal images. The measurements of intensities (cell, cytosol, plasma membrane) are not affected by this. "
	+"Note that the macro has been tested with a limited set of deconvolved images from a wide-field microscope (solely for the purposes of <i>Zahumensky et al., 2022</i>). "
	+"Proceed with caution and verify that the results make sense.<br>"
	+"</html>";

Dialog.create("Quantify");
	Dialog.addDirectory("Directory:", "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-008-180817 - Nce102 vs SL biosynthesis inhibition/211019/");
//	Dialog.addDirectory("Directory:", "");
	Dialog.addString("Subset (optional):", subset_default);
	Dialog.addString("Channel:", ch);
	Dialog.addString("Naming scheme:", "strain,medium,time,condition,frame", 33);
	Dialog.addString("Experiment code scheme:", "XY-M-000", 33);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addNumber("Cell size from:", cell_size_min);
	Dialog.addToSameRow();
	Dialog.addNumber("to:","Infinity",0,6, fromCharCode(181) + "m^2");
	Dialog.addNumber("Coefficient of variance (CV) threshold", 0);
	Dialog.addChoice("Deconvolved:", boolean ,"no");
	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
//	Dialog.addChoice("Save segmentation masks (tangential only)", boo, "no");
	Dialog.addHelp(html0);
    Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	subset = Dialog.getString();
	channel = Dialog.getString();
	naming_scheme = Dialog.getString();
	experiment_scheme = Dialog.getString();
	image_type = Dialog.getChoice();
	cell_size_min = Dialog.getNumber();
	cell_size_max = Dialog.getNumber();
	CV = Dialog.getNumber();
	deconvolved = Dialog.getChoice();
//	SaveMasks = Dialog.getChoice();
	//for deconvolved images (based on testing, not theory):

if (!endsWith(dir, "/"))
	dir = dir + "/";

if (deconvolved == "yes") {
	Gauss_Sigma = 0; //no smoothing is used
	PatchProminence = 1.333; //patch prominence can be set lower compared to regular confocal images
}

dirMaster = dir; //directory into which Result summary is saved

if (matches(image_type, "transversal")) {
	dirType="data";
} else {
	dirType="data-caps";
}

//dirType = "data-"+image_type+"/";
//ROIsdirType = "ROIs-"+image_type+"/";

CHANNEL = sort_channels(channel);
for (ii = 0; ii <= CHANNEL.length-1; ii++){
	ch = CHANNEL[ii];
	temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
//	master_files = getFileList(dirMaster);
//	if (contains(master_files, temp_file))
	if (contains(getFileList(dirMaster), temp_file))
		temp_files_count++;
}
if (temp_files_count > 0)
	continue_analysis = getBoolean("Incomplete analysis dectected.", "Continue previous analysis", "Start fresh");

countFiles(dir);

for (ii = 0; ii <= CHANNEL.length-1; ii++){
	ch = CHANNEL[ii];
	temp_file = "results-temporary_" + image_type + "_channel_"+ ch +".csv";
	no_ROI_files = "files_without_ROIs_" + image_type + "_channel_"+ ch +".tsv";
	processed_files = "processed_files_" + image_type + "_channel_"+ ch +".tsv";
	initialize();
	processFolder(dir);
	channel_wrap_up();
}
final_wrap_up();

//////////////////////////////////////////////
//definitions of functions used in the macro//
//////////////////////////////////////////////
function processFolder(dir) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		showProgress(i+1, list.length);
		if (endsWith(list[i], "/"))
        	processFolder(""+dir+list[i]);
	    else {
			q = dir+list[i];
			if (endsWith(dir, dirType+"/") && indexOf(proc_files, q) < 0 && indexOf(q, subset) >= 0)
				if (check_ROIs(dir, list[i])){
					extIndex = lastIndexOf(q, ".");
					ext = substring(q, extIndex+1);
					if (contains(extension_list, ext)){
						print("\\Update: Processing "+ counter +" out of " + count-proc_files_number + " files");
						if (matches(image_type, "transversal")) measure_transversal();
							else measure_tangential();
						counter++;	
					}
				}
		}
	}
}

function countFiles(dir) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			countFiles("" + dir + list[i]);
		else {
			q = dir+list[i];
			if (endsWith(dir, dirType+"/") && indexOf(proc_files, q) < 0 && indexOf(q, subset) >= 0){
				count++;
				open(dir + list[i]);
				getDimensions(width, height, channels, slices, frames);
				Array.getStatistics(CHANNEL, CHANNEL_min, CHANNEL_max, CHANNEL_mean, CHANNEL_stdDev);
				if (channels < CHANNEL_max)
					exit("One or more images in the data set do not have one or more selected channels ("+ channels +"). Check your data and restart analysis.");
				close();
			}
		}
	}
}

function contains(array, value) {
    for (i=0; i < array.length; i++)
        if (array[i] == value) return true;
    return false;
}

function sort_channels(channel){
	if (channel <= 0)
		exit("Selected channel ("+ channel +") does not exit.");
	if (indexOf(channel, "-") >= 0){
		X = "--";
		channel_temp = split(channel,"--");
		channel_temp = Array.sort(channel_temp);
		j = 0;
		for (i = channel_temp[0]; i <= channel_temp[1]; i++){
			CHANNEL[j] = i;
			j++;
		}
	} else
		CHANNEL = split(channel,",,");
	return CHANNEL;
}

function check_ROIs(dir, string){
	title = substring(string, 0, lastIndexOf(string, "."));
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (File.exists(roiDir + title + "-RoiSet.zip")){
		return true;
	} else {
		print("["+no_ROI_files+"]",q+"\n");
		selectWindow(no_ROI_files);
		saveAs("Text", dirMaster + no_ROI_files);
		return false;
	}
}

function prep() {
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (SaveMasks == true) {
		patchesDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "patches")+"/";
		if (!File.exists(patchesDir))
			File.makeDirectory(patchesDir);
	}
	open(q);
	rename(list[i]);
	title = File.nameWithoutExtension;
	bit_depth = bitDepth();
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	run("Clear Results");
	run("Measure");
	Image_Area = getResult("Area", 0);
	Stack.setChannel(ch);
	selectWindow(list[i]);
		run("Duplicate...", "title=DUP_CLAHE channels="+ch);
		run("Normalize Local Contrast", "block_radius_x=5 block_radius_y=5 standard_deviations=10 center stretch");
		run("Enhance Local Contrast (CLAHE)", "blocksize=8 histogram=64 maximum=3 mask=*None*");
		run("Unsharp Mask...", "radius=1 mask=0.6");
		run("Gaussian Blur...", "sigma=Gauss_Sigma");
	
	if (matches(image_type, "transversal")) {
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_Gauss channels="+ch);
			run("Gaussian Blur...", "sigma=Gauss_Sigma");
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_mean channels="+ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_dotfind channels="+ch);
			run("Convolve...", "text1=[1 1 1\n1 1 1\n1 1 1\n] normalize");
			run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 0 0 0 -1\n-1 0 16 0 -1\n-1 0 0 0 -1\n-1 -1 -1 -1 -1\n]");
			run("Subtract Background...", "rolling=5");
			changeValues("-Infinity", -1, 0);
		watershed_segmentation();
	}
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
}

//To get an estimate of the image background, the background is subtracted in the original image using brutal force.
//The result is then subtracted from the original image, creating an image of the background. Mean intensity of this image is then used as background intensity estimate.
function measure_background(image_title) {
	selectWindow(image_title);
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "duplicate channels="+ch);
	run("Select None");
	run("Clear Results");
	run("Measure");
	MIN = getResult("Min", 0); //if offset is set correctly during image acquisition, zero pixel intensity usually originates when multichannel images are aligned. In this case, they need to be cropped before the background estimation
		if (MIN == 0) run("Auto Crop (guess background color)");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-BC");
	run("Subtract Background...", "rolling=" + width + " stack");
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
	run("Clear Results");
	run("Measure");
	MEAN = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, MEAN);
	run("Create Selection");
	run("Measure");
	run("Select None");
	BC_image = getResult("Mean", 1);
	close("DUP-CROP-BC");
	close("DUP-CROP");
	close("Result of DUP-CROP");
	return BC_image;
}

function find_parents() {
	parent = File.getParent(dir); //BR date
	grandparent = File.getParent(parent); //for exp code
	BR_date = replace(File.getName(parent)," ","_");
	exp_code = replace(File.getName(grandparent)," ","_");
	if (lengthOf(BR_date) > 6)
		BR_date = substring(BR_date, 0, 6);
	if (lengthOf(exp_code) > lengthOf(experiment_scheme))
		exp_code = substring(exp_code, 0, lengthOf(experiment_scheme));
	return newArray(exp_code, BR_date);
}

function measure_transversal() {
	prep();
	BC = measure_background(list[i]);
	//quantification - open ROIs prepared with ROI_prep.ijm macro and cycle through them one by one
	init = 0;
	numROIs = roiManager("count");
	//the shortened loop can be used for testing; activated in line 2
	if (test == 1){
		init = 4;
		numROIs = 8;
	}
	for(j = init; j < numROIs; j++) {
// measure cell characteristics: area, integral_intensity_BC, mean_intensity_BC, intensity_SD, intensity_CV
// 0.166 makes the ROI slightly bigger to include the whole plasma membrane:  
		cell = measure_ROI(list[i], j, 0.166); //measures cell characteristics and returns them in an array: area, integral_intensity_BC, mean_intensity_BC, SD, CV; 0.166 increases the ROI size to include the whole PM
		//shape characterization from the Results table created by the measure_ROI function
		major_axis = getResult("Major", 0);
		minor_axis = getResult("Minor", 0);
		eccentricity = sqrt(1-pow(minor_axis/major_axis, 2));
		// only analyse cells that fall into the cell size range and CV specified by the user when the macro is run
		// cell[0] corresponds to cell area; cell[4] to intensity CV
		if (cell[0] > cell_size_min && cell[0] < cell_size_max && cell[4] > CV){
			run("Create Mask"); // creates a mask of the entire cell; preparation for plasma membrane segmentation
			rename("Mask-cell");
			cytosol = measure_ROI(list[i], j, -0.166); //measures cytosol characteristics and returns them in an array: area, integral_intensity_BC, mean_intensity_BC, SD, CV; -0.166 makes the ROI smaller to only include cytosol
			run("Create Mask"); //creates a cytosol mask; preparation for plasma membrane segmentation
			rename("Mask-cytosol");
		//plasma membrane segmentation
			imageCalculator("Subtract create", "Mask-cell","Mask-cytosol");
			selectWindow("Result of Mask-cell");
			run("Create Selection"); //selection of the plasma membrane only from the computed mask
			selectWindow(list[i]);
			run("Restore Selection"); //transfer of the selection to the RAW microscopy image (i.e., no smoothing or any other processing)
			plasma_membrane = measure_area_selection(); //measures plasma membrane characteristics and returns them in an array: area, integral_intensity_BC, mean_intensity_BC, SD, CV

//patches quantified from intensity profiles
			patches_from_intensity_profile_Gauss = patches_from_intensity_profile("DUP_Gauss","Infinity");
			base_of_PM = PM_base_BC;
//			patch_distribution = charaterize_patch_distribution(patch_numbers[0]); //patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev, patch_distance_CV
			patches_from_intensity_profile_CLAHE = patches_from_intensity_profile("DUP_CLAHE","Infinity");
			patches_from_intensity_profile_dotfind = patches_from_intensity_profile("DUP_dotfind","Infinity");
		
//patches quantified from thresholding			
			patches_from_thresholding_Gauss = patches_from_thresholding("DUP_Gauss");
			patches_from_thresholding_CLAHE = patches_from_thresholding("DUP_CLAHE");
			patches_from_thresholding_dotfind = patches_from_thresholding("DUP_dotfind");
	
			watershed_patches = count_watershed_patches();

			prot_fraction_in_patches = (1-base_of_PM/plasma_membrane[2])*100;
			PM_div_Cyt = plasma_membrane[2]/cytosol[2];
			cyt_div_cell = cytosol[2]/cell[2]; //ratio of BC corrected mean intensities
			PM_div_cell = plasma_membrane[2]/cell[2];
			cyt_div_cell_I_integral = cytosol[1]/cell[1]; //ratio of BC corrected integral intensities
			PM_div_cell_I_integral = plasma_membrane[1]/cell[1];

			parents = find_parents();
			print("["+temp_file+"]",parents[0]+","+parents[1] //experiment code, biological replicate date
				+","+replace(title," ","_")+","+BC+","+(j+1)
//				+","+patch_numbers[0]+","+patch_numbers[1]+","+patch_numbers[2]+","+PM_base_BC+","+patch_numbers[3] //patches, patch_density, patch_intensity_BC, patch_prominence
				+","+patches_from_intensity_profile_Gauss[0]+","+patches_from_intensity_profile_Gauss[1]+","+patches_from_intensity_profile_Gauss[2]+","+base_of_PM+","+patches_from_intensity_profile_Gauss[3] //patches, patch_density, patch_intensity_BC, patch_prominence
				+","+cell[0]+","+cell[1]+","+cell[2]+","+cell[3]+","+cell[4] // cell parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+cytosol[0]+","+cytosol[1]+","+cytosol[2]+","+cytosol[3]+","+cytosol[4] // cytosol parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+plasma_membrane[0]+","+plasma_membrane[1]+","+plasma_membrane[2]+","+plasma_membrane[3]+","+plasma_membrane[4]// plasma membrane parameters: area, integral_intensity_BC, mean_intensity_BC, SD, CV
				+","+PM_div_Cyt
//				+","+prot_fraction_in_patches+","+patch_distribution[0]+","+patch_distribution[1]+","+patch_distribution[2]+","+patch_distribution[3]+","+patch_distribution[4] //patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV
				+","+PM_div_cell+","+cyt_div_cell+","+PM_div_cell_I_integral+","+cyt_div_cell_I_integral+","+major_axis+","+minor_axis+","+eccentricity+","+patches_from_intensity_profile_Gauss[4] //patches_outliers at the end
				+","+patches_from_intensity_profile_CLAHE[0]+","+patches_from_intensity_profile_CLAHE[1]
				+","+patches_from_intensity_profile_dotfind[0]+","+patches_from_intensity_profile_dotfind[1]
				+","+patches_from_thresholding_Gauss[0]+","+patches_from_thresholding_Gauss[1]
				+","+patches_from_thresholding_CLAHE[0]+","+patches_from_thresholding_CLAHE[1]
				+","+patches_from_thresholding_dotfind[0]+","+patches_from_thresholding_dotfind[1]
				+","+watershed_patches[0]+","+watershed_patches[1]
			+"\n");
			close("Mask-cell");
			close("Mask-cytosol");
			close("Mask-cyt-outer");
			close("Mask-cyt-inner");
			close("Result of Mask-cell");
			close("Result of Mask-cyt-outer");
		}
	}
	close("*");
	save_temp();
}

function measure_tangential() {
	prep();
	BC = measure_background(list[i]);
	numROIs = roiManager("count");
//count eisosomes using the "Find Maxima" plugin
	for(j = 0; j < numROIs; j++) {
//	for(j = numROIs-3; j < numROIs; j++) {
		
	select_window(list[i]);
		select_ROI(j);
		run("Duplicate...", "title=DUP_cell duplicate channels="+ch);
	//measure cell parameters from raw image (size, fluorescence intensity, major axis of the ellipse used for fitting the ROI
		run("Clear Results");
		run("Measure");
		Area = getResult("Area", 0);
		cell_I_mean = getResult("Mean", 0);
		cell_I_mean_BC = cell_I_mean-BC; //background correction
		cell_I_SD = getResult("StdDev", 0); //standard deviation of the mean intensity (does not change with background)
		cell_CV = cell_I_SD/cell_I_mean_BC;
		major_axis = getResult("Major", 0);
		if (Area > cell_size_min && Area < cell_size_max){ //continue if the cell size falls between the lower and upper limit
//			if (cell_CV > 0.3){ //a cell (tangential section) is only considered to have microdomains if the CV (i.e,. SD/mean) is greater than 0.3 (empirical)
		//analyze patch density from the image with local contrast adjustment
			select_window("DUP_CLAHE");
			select_ROI(j);
//			Delta = major_axis/3*(1-sqrt(2/3)); //D - delta; the ROI is made smaller by this amount in the following step to exclude background areas from the analysis
			Delta = major_axis/2*(1-sqrt(2/3)); //D - delta; the ROI is made smaller by this amount in the following step to exclude background areas from the analysis
			run("Enlarge...", "enlarge=-"+Delta);
			run("Clear Results");
			run("Measure");
			ROI_area = getResult("Area", 0); //used below to calculate patch density
//	CV_ROI = getResult("StdDev", 0)/getResult("Mean", 0);
//waitForUser(CV_ROI);
			cell_BC_CLAHE = measure_cell_background(); //measures mean and SD of the intensity of area among patches; serves as baseline for maxima identification and thresholding
			patch_prom = cell_BC_CLAHE[0]*0.1;//mean
//			patch_prom = cell_BC[1]*2; //SD
			no_of_patches = 0;
			run("Clear Results");
//			run("Find Maxima...", "prominence=patch_prom strict exclude output=Count");
			run("Find Maxima...", "prominence=patch_prom exclude output=Count");
			if (cell_CV > CV_threshold) //if the CV is not greater than CV_threshold (set to 0.3 by def.), the cells are deemed to have no microdomains
				no_of_patches = getResult("Count", 0);
			patch_density_find_maxima = no_of_patches/ROI_area;
		//patch quantification via thresholding and "Analyze particles..." plugin
		//setting initial values that are witten into the Results table if no patches are detected
			area_fraction = 0;
			size = NaN;
			size_SD = NaN;
			length = NaN;
			length_SD = NaN;
			width = NaN;
			width_SD = NaN;
			density = 0;
			MEAN2 = NaN;
			patch_I_mean_BC = NaN;
			patch_I_SD = NaN;
		//make mask from current ROI, setting the Threshold based on the intensity of signal in between patches
			if (no_of_patches > 0) {
				select_window("DUP_CLAHE");
				select_ROI(j);
				run("Enlarge...", "enlarge=-"+Delta);
				run("Duplicate...", "title=DUP duplicate channels="+ch);
				run("Select None");
//				setThreshold(cell_BC_CLAHE[0]+cell_BC_CLAHE[1], pow(2,bit_depth)-1);
				setThreshold(cell_BC_CLAHE[0]+3*cell_BC_CLAHE[1], pow(2,bit_depth)-1);
				run("Create Mask");
				rename("MASK");
				run("Adjustable Watershed", "tolerance=0.01");
/*
if (SaveMasks == true) {
	saveAs("PNG", patchesDir+list[i]+"-"+j);
	rename("MASK");
}
*/
				run("Clear Results");
				run("Measure");
				mask_mean = getResult("Mean", 0);
				if (mask_mean > 0) { //proceed only if there is any signal
					run("Restore Selection");
					setBackgroundColor(0, 0, 0);
					run("Clear Outside");
					setBackgroundColor(255, 255, 255);
					run("Enlarge...", "enlarge=1 pixel");
					run("Translate...", "x=-1 y=-1 interpolation=None");
					run("Clear Results");
					run("Analyze Particles...", "size="+5*pow(pixelHeight,2)+"-"+120*pow(pixelHeight,2)+" show=Nothing display exclude clear stack"); //only particles that take at least 5 pixels (smallest possible cross) are included
					no_of_patches = nResults;
					if (no_of_patches > 0) { //get info if there is a single patch
						size = getResult("Area", 0);
						length = getResult("Major", 0);
						width = getResult("Minor", 0);
						density = no_of_patches/ROI_area;
						area_fraction = size*density*100;
					}
					if (no_of_patches > 1) { //summarize only if there is more than one patch (it does not work when there is a single result...)
						run("Summarize");
						size = getResult("Area", no_of_patches);
						size_SD = getResult("Area", no_of_patches+1);
						length = getResult("Major", no_of_patches);
						length_SD = getResult("Major", no_of_patches+1);
						width = getResult("Minor", no_of_patches);
						width_SD = getResult("Minor", no_of_patches+1);
						density = no_of_patches/ROI_area;
						area_fraction = size*density*100;
					}
					selectWindow("MASK");
					run("Translate...", "x=1 y=1 interpolation=None");		
					run("Create Selection");
					selectWindow("DUP_cell");
					run("Restore Selection");
					run("Clear Results");
					run("Measure");
					patch_I_mean = getResult("Mean", 0);
					patch_I_mean_BC = patch_I_mean-BC;
					patch_I_SD = getResult("StdDev", 0);
				}
				close("MASK");
				close("DUP");
				close("DUP2");
				close("DUP_cell");
			}
			parents = find_parents(); //exp_code, BR_date
			print("["+temp_file+"]",parents[0]+","+parents[1]
				+","+replace(title," ","_")+","+BC+","+j+1
				+","+patch_density_find_maxima+","+density+","+area_fraction
				+","+length+","+length_SD+","+width+","+width_SD+","+size+","+size_SD
				+","+patch_I_mean_BC+","+patch_I_SD
				+","+"\n");
		}
	}
	close("*");
	save_temp();
}

//prepare Fiji and find out if previous analysis run concluded
function initialize(){
	close("*");
	if(isOpen("Log"))
		close("Log");
	if(isOpen(temp_file))
		print("["+temp_file+"]","\\Close");		
	if(isOpen(processed_files))
		print("["+processed_files+"]","\\Close");
	if(isOpen(no_ROI_files))
		print("["+no_ROI_files+"]","\\Close");
	setBackgroundColor(255, 255, 255); //this is important for proper work with masks
	run("Set Measurements...", "area mean standard modal min integrated centroid fit redirect=None decimal=5");
	run("Text Window...", "name=["+temp_file+"] width=180 height=40");
	setLocation(0,0);
	run("Text Window...", "name=["+processed_files+"] width=180 height=20");
	setLocation(0,screenHeight/2);
	run("Text Window...", "name=["+no_ROI_files+"] width=90 height=20");
	setLocation(screenWidth*2/3,screenHeight/2);
	if (continue_analysis == 1){
		if (File.exists(dirMaster + no_ROI_files)){
			File.delete(dirMaster + no_ROI_files);
			close("Log");
		}
		print("["+temp_file+"]", File.openAsString(dirMaster + temp_file));
		proc_files = File.openAsString(dirMaster + processed_files);
		print("["+processed_files+"]", proc_files);
		proc_files_array = split(proc_files,"\n");
		proc_files_number = proc_files_array.length;
	} else
		print_header();
}

//print the header of the Results output file
function print_header(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
//	print("["+temp_file+"]",
//print("\\Clear");
	print("["+temp_file+"]","# Basic macro run statistics:"+"\n");
	print("["+temp_file+"]","# Date and time: " + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + " " + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2)+"\n");
	print("["+temp_file+"]","# Macro version: " + version+"\n");
	print("["+temp_file+"]","# Channel: " + ch+"\n");
	print("["+temp_file+"]","# Cell (ROI) size interval: " + cell_size_min + "-" + cell_size_max +" um^2"+"\n");
	print("["+temp_file+"]","# Coefficient of variance threshold: " + CV+"\n");
	if (matches(image_type, "transversal")) {
		print("["+temp_file+"]","# Smoothing factor (Gauss): " + Gauss_Sigma+"\n");
		print("["+temp_file+"]","# Patch prominence: " + PatchProminence+"\n");
	}
	print("["+temp_file+"]","#"+"\n"); //emptyline that is ignored in bash and R
	//the parameters quantified from transversal and tangential focal planes are necessarily different. Hence, the columns in the Results file are also different
	if (matches(image_type, "transversal"))
		print("["+temp_file+"]","exp_code,BR_date,"
			+ naming_scheme + ",mean_background,cell_no"
			+",patches,patch_density,patch_intensity,PM_base,patch_prominence"
			+",cell_area,cell_I.integral,cell_I.mean,cell_I.SD,cell_I.CV"
			+",cytosol_area,cytosol_I.integral,cytosol_I.mean,cytosol_I.SD,cytosol_I.CV"
			+",PM_area,PM_I.integral,PM_I.mean,PM_I.SD,PM_I.CV"
			+",PM_I.div.Cyt_I(mean)"
//			+",prot_in_patches,patch_distance_min,patch_distance_max,patch_distance_mean,patch_distance_stdDev,patch_distance_CV"
			+",PM_I.div.cell_I(mean),Cyt_I.div.cell_I(mean),PM_I.div.cell_I(integral),Cyt_I.div.cell_I(integral)"
			+",major_axis,minor_axis,eccentricity,patches_outliers"
			+",patches_profile_CLAHE,patch_density_profile_CLAHE"
			+",patches_profile_dotfind,patch_density_profile_dotfind"
			+",patches_threshold_Gauss,patch_density_threshold_Gauss"
			+",patches_threshold_CLAHE,patch_density_threshold_CLAHE"
			+",patches_threshold_dotfind,patch_density_threshold_dotfind"
			+",patches_from_watershed,patch_density_from_watershed"
			+"\n"
		);
	else
		print("["+temp_file+"]","exp_code,BR_date," + naming_scheme + ",mean_background,cell_no,patch_density(find_maxima),patch_density(analyze_particles),area_fraction(patch_vs_ROI),length,length_SD,width,width_SD,size,size_SD,mean_patch_intensity,mean_patch_intensity_SD"+"\n");
	setLocation(0,0);
}

function save_temp(){
	selectWindow(temp_file);
	saveAs("Text", dirMaster + temp_file);
	setLocation(0, 0);
	print("["+processed_files+"]", q + "\n");
	selectWindow(processed_files);
	saveAs("Text", dirMaster + processed_files);
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function channel_wrap_up(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	res = "Results of " + image_type + " image analysis, channel " + ch + " (" + year + "-" + String.pad(month + 1,2) + "-" + String.pad(dayOfMonth,2) + "," + String.pad(hour,2) + "-" + String.pad(minute,2) + "-" + String.pad(second,2) + ").csv";
	selectWindow(temp_file);
	saveAs("Text", dirMaster + res);
	close("Results");
	close("ROI manager");
	print("["+processed_files+"]","\\Close");
	print("["+no_ROI_files+"]","\\Close");
	print("["+res+"]","\\Close");
	if (File.length(dirMaster + no_ROI_files) == 0){
		File.delete(dirMaster + temp_file);
//		close("Log");
	}
	close("Log");
}

//saving of the output in csv format and cleaning up the Fiji (ImageJ) space
function final_wrap_up(){
	setBackgroundColor(0, 0, 0); //reverts the backgroudn to default ImageJ settings
	processed_files_count = 0;
	no_ROI_files_count = 0;
	for (ii = 0; ii <= CHANNEL.length-1; ii++){
		ch = CHANNEL[ii];
		processed_files = "processed_files_" + image_type + "_channel_"+ ch +".tsv";
		no_ROI_files = "files_without_ROIs_" + image_type + "_channel_"+ ch +".tsv";
		if (File.length(dirMaster + processed_files) > 0)
			processed_files_count++;
		if (File.length(dirMaster + no_ROI_files) > 0)
			no_ROI_files_count++;
	}
	if (processed_files_count == 0)
		waitForUser("This is curious...", "No images were analysed. Check if you had prepared ROIs before you ran the analysis.");
	else
		if (File.length(dirMaster + no_ROI_files) > 0)
			waitForUser("Finito!", "Analysis finished successfully, but one or more images were not processed due to missing ROIs.\nThese are listed in the \"files_without_ROIs\" file.");
		else
			waitForUser("Finito!", "Analysis finished successfully."); //informs the user that the analysis has finished successfully
}

//following code analyses distribution of fl. maxima along the plasma membrane: shortest, longest, average distance, and coeffcient of variance of their distribution (a measure of uniformity)
//for this purpose, PM_add variable is introduced to allow for the measurement of distance between the last and first fl. maxima along the plasma membrane
function charaterize_patch_distribution(patches){
	patch_distance_min = NaN;
	patch_distance_max = NaN;
	patch_distance_mean = NaN;
	patch_distance_stdDev = NaN;
	patch_distance_CV = NaN;
	if (patches > 1) {
		MAXIMA = newArray(patches);
		for (p = 0; p < patches; p++){
//						for (p=patches_outliers; p<patches; p++){ //at this point, maxima are ordered by intensity; starting at "patches_outliers" makes the algorithm discart P-bodies
			MAXIMA[p] = getResult("X1",p);
		}
		Array.sort(MAXIMA);//sorts positions of the intensity maxima in ascending manner
		PM_add = PM_length+MAXIMA[0];
		if (PM_add > MAXIMA[MAXIMA.length-1]) MAXIMA = Array.concat(MAXIMA, PM_add);
			else patches = patches-1;
		patch_distance = newArray(MAXIMA.length-1);
		for (p = 0; p < MAXIMA.length-1; p++){
		 	patch_distance[p] = MAXIMA[p+1]-MAXIMA[p];
		}
		Array.getStatistics(patch_distance, patch_distance_min, patch_distance_max, patch_distance_mean, patch_distance_stdDev);
		patch_distance_CV = patch_distance_stdDev / patch_distance_mean;
	}
	return newArray(patch_distance_min, patch_distance_max,	patch_distance_mean, patch_distance_stdDev, patch_distance_CV);
}

function get_PM_base(ROI_no){
	select_ROI(ROI_no);
	run("Area to Line");
	profile = getProfile();
	Array.getStatistics(profile, profile_min, profile_max, profile_mean, profile_stdDev);
	minIndices = Array.findMinima(profile, 1.5*profile_stdDev, 1);
	minima = newArray(0);
	M = 0;
	for (jj = 0; jj < minIndices.length; jj++){
		x = minIndices[jj];
		minima[jj] = profile[x];
	}
	Array.getStatistics(minima, minima_min, minima_max, minima_mean, minima_stdDev);
	if (minima.length == 0)
		minima_mean = (profile_mean+profile_min)/2;
	return newArray(minima_mean, minima_stdDev);
//	return minima_mean;
}

function measure_ROI(win_title, j, buff){
	select_window(win_title);
	select_ROI(j);
	run("Enlarge...", "enlarge="+buff);
	measurements = measure_area_selection();
	return measurements;
}

function measure_area_selection(){
	run("Clear Results");
	run("Measure");
	area = getResult("Area", 0); //area of cell interior
	integral_intensity = getResult("IntDen", 0); //integrated fluorescence intensity
	integral_intensity_BC = integral_intensity - area * BC; //backgorund correction
	mean_intensity = getResult("Mean", 0); //mean fluorescence intensity
	mean_intensity_BC = mean_intensity - BC; //background correction
	SD = getResult("StdDev", 0); //standard deviation of the mean intracellular intensity
	CV = SD/mean_intensity_BC; 
	return newArray(area, integral_intensity_BC, mean_intensity_BC, SD, CV);
}

function measure_cort(win_title, ROI_no){
	select_window(win_title);
	select_ROI(ROI_no);
	run("Enlarge...", "enlarge=-0.249");
//	run("Enlarge...", "enlarge=-0.166");
	run("Create Mask");
	rename("Mask-cyt-outer");
	selectWindow(list[i]); //selects raw microscopy image again
	select_window(list[i]);
	select_ROI(j);
	run("Enlarge...", "enlarge=-0.415");
//	run("Enlarge...", "enlarge=-0.332");
	run("Create Mask");
	rename("Mask-cyt-inner");
	imageCalculator("Subtract create", "Mask-cyt-outer","Mask-cyt-inner");
	selectWindow("Result of Mask-cyt-outer");
	run("Create Selection");
	selectWindow(list[i]);
	run("Restore Selection"); //transfer of the selection to the raw microscopy image
	run("Clear Results");
	run("Measure");
	CortCyt_mean = getResult("Mean", 0);
	CortCyt_mean_BC = CortCyt_mean - BC;
	CortCyt_mean_SD = getResult("StdDev", 0);
	return newArray(CortCyt_mean, CortCyt_mean_SD);
}

function clean(membrane_buff){
	D = membrane_buff*0.166;
	roiManager("Select", j);
	run("Enlarge...", "enlarge=-"+D);
	run("Clear", "slice");
	roiManager("Select", j);
	run("Enlarge...", "enlarge="+D);
	run("Clear Outside");
	run("Select None");
}

function select_window(window_title){
	selectWindow(window_title);
	while(!(getTitle == window_title)){
		wait(1);
		selectWindow(window_title);
	}
}

function select_ROI(j){
	roiManager("Select", j);
	while(selectionType() == -1){
		wait(1);
		roiManager("Select", j);
	}
}

function patches_from_intensity_profile(win_title,rel_outlier_intensity){
	PM_from_line = measure_PM(win_title, j);
	select_ROI(j);
	PM_from_area = measure_area_selection();
	cortical_cytosol = measure_cort(win_title, j); //array: mean, SD; neither corrected for BC; serves for direct comparison of intensities when PM microdomains are counted
	BC_win_title = measure_background(win_title);
	PM_base = get_PM_base(j);
	PM_base_BC = PM_base[0] - BC_win_title;
	if ((cortical_cytosol[0] - BC_win_title) > PM_from_area[2]) { //if the mean intensity of cortical cytosol is greater than the mean intensity in the plasma membrane (happens in the case that the protein is (mostly) cytosolic, due to how the ROIs are drawn)
		Peak_MIN = PatchProminence*cortical_cytosol[0]+BC_win_title;
	} else {
		Peak_MIN = PatchProminence*PM_base_BC+BC_win_title;
	}
	select_window(win_title);
	select_ROI(j);
	run("Area to Line");
	profile = getProfile();
	Array.getStatistics(profile, profile_min, profile_max, profile_mean, profile_stdDev);
	maxIndices = Array.findMaxima(profile, profile_stdDev/2, 2);
	maxima = newArray(0);
	M = 0;
	patch_outliers = 0;
	for (jj = 0; jj < maxIndices.length; jj++){
		x = maxIndices[jj];
		if ((profile[x]-BC_win_title)/PM_base_BC > rel_outlier_intensity){
			patch_outliers++;
		} else
			if (profile[x] > Peak_MIN){
				maxima[M] = profile[x];
				x = maxIndices[jj];
			M++;
			}
	}
	Array.getStatistics(maxima, maxima_min, maxima_max, maxima_mean, maxima_stdDev);
    patches = maxima.length;
	patch_intensity_BC = maxima_mean-BC_win_title;
	patch_density = patches/PM_from_line[0];
	mean_patch_prominence = patch_intensity_BC/PM_base_BC;
	return newArray(patches, patch_density, patch_intensity_BC, mean_patch_prominence, patch_outliers);
}

//watershed segmentation gives much better results - MYR treated cells need to be checked. Other than that, WS segm appears to be the best option so far
function patches_from_thresholding(win_title){
	select_window(win_title);
	run("Select None");
	run("Duplicate...", "duplicate channels="+ch);
//	rename("DUP");
	
	PM = measure_PM(win_title, j); //PM[0] - length, PM[1] - mean intensity
//	setThreshold(PM[1], pow(2,bit_depth)-1);
//	PM_base = get_PM_base(j);
	BC_win_title = measure_background(win_title+"-1");
//	PM_base_BC = get_PM_base(j) - BC_win_title;
	PM_base = get_PM_base(j);
	PM_base_BC = PM_base[0] - BC_win_title;
	setThreshold(PatchProminence*PM_base_BC + PM_base[1] + BC_win_title, pow(2,bit_depth)-1);
//	setThreshold(PatchProminence*PM_base_BC + BC_win_title, pow(2,bit_depth)-1);
	run("Convert to Mask");
	imageCalculator("Multiply", win_title+"-1", "PM_mask-WS");
	run("Despeckle");
	run("Adjustable Watershed", "tolerance=0.1");
	run("Convert to Mask");
	select_ROI(j);
	delta = 0.166;
	run("Enlarge...", "enlarge=" + delta);
	run("Analyze Particles...", "size=0.01-0.03 circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.02-" + size_MAX +" circularity=0.50-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0.03-0.20 circularity=0.75-1.00 show=Overlay display clear overlay");
//	run("Analyze Particles...", "size=0-0.36 circularity=0.50-1.00 show=Overlay display clear overlay");
	patches = nResults;
	patch_density = patches/PM[0];
	close(win_title+"-1");
	return newArray(patches, patch_density);
}

function measure_PM(win_title, ROI_no){
	select_window(win_title);
	select_ROI(ROI_no);
	run("Area to Line"); //convert the ellipse (area object) to a line that has a beginning and end
	run("Line Width...", "line="+0.332/pixelHeight);
	run("Clear Results");
	run("Measure");
		PM_mean = getResult("Mean", 0);
		PM_length = getResult("Length", 0);
	return newArray(PM_length, PM_mean);
}

function measure_cell_background() {
	run("Duplicate...", "duplicate");
	rename("DUP-CROP");
	run("Duplicate...", "duplicate");
	rename("DUP-CROP-BC");
	getDimensions(cell_width, height, channels, slices, frames);
	run("Subtract Background...", "rolling=" + cell_width);
	imageCalculator("Difference create stack", "DUP-CROP", "DUP-CROP-BC");
	run("Clear Results");
	run("Restore Selection");
	run("Measure");
	cell_mean = getResult("Mean", 0);
	selectWindow("DUP-CROP");
	setThreshold(0, 1.3*cell_mean);
	run("Select None");
	run("Create Mask");
	run("Restore Selection");
	setBackgroundColor(0, 0, 0);
	run("Clear Outside");
	run("Create Selection");
	selectImage("DUP-CROP");
	run("Restore Selection");
	run("Measure");
	cell_background = getResult("Mean", 1);
	cell_background_SD = getResult("StdDev", 1);
	close("DUP-CROP-BC");
	close("DUP-CROP");
	close("Result of DUP-CROP");
	close("mask");
	setBackgroundColor(255, 255, 255);
	return newArray(cell_background, cell_background_SD);
}

function watershed_segmentation(){
	roiManager("reset");
	roiManager("Open", roiDir+title+"-RoiSet.zip");
	roiManager("Remove Channel Info");
	watershedDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "watershed_segmentation-ch")+ch+"/";
	if (!File.exists(watershedDir))
		File.makeDirectory(watershedDir);
	if (File.exists(watershedDir+title+"-WS.png")){
		open(watershedDir+title+"-WS.png");
		rename("Watershed-Segmented");
	} else {
		selectWindow(list[i]);
			run("Duplicate...", "title=DUP_watershed channels="+ch);
			run("Select None");
			run("8-bit");
			run("Watershed Segmentation", "blurring='0.0'   watershed='1 1 0 255 1 0'   display='2 0' ");
			while(!isOpen("Dams"))
				wait(1);
			selectWindow("Binary watershed lines");
			run("Despeckle");
			saveAs("PNG", watershedDir+title+"-WS");
			rename("Watershed-Segmented");
			close("Dams");
	}
	selectImage(list[i]);
	bounds = newArray(-1, 2);
	names = newArray("inner", "outer");
	delta = 5*pow(0.166,2)/pixelWidth;
	numROIs = roiManager("count");
	for (k = 0; k <= 1; k++){
		for (j = 0; j < numROIs; j++){
			roiManager("select", j);
			run("Enlarge...", "enlarge=" + bounds[k]*delta+" pixel");
			roiManager("update");
		}
		roiManager("show all without labels");
		run("ROI Manager to LabelMap(2D)");
		run("Grays");
		setMinAndMax(0, 1);
		run("Apply LUT");
		rename(names[k]);
	}
	imageCalculator("Difference create", names[0], names[1]);
	rename("PM_mask-WS");
	
	selectWindow("Watershed-Segmented");
	run("Invert");
	imageCalculator("Multiply", "Watershed-Segmented", "PM_mask-WS");
	run("Despeckle");
	run("Convert to Mask");
	saveAs("PNG", watershedDir+title+"-WS_patches");
	rename("WS_patches");
}

function count_watershed_patches(){
	selectWindow("WS_patches");
	delta = 5*pow(0.166,2)/pixelWidth;
	size_MAX = 0.36/pow(pixelWidth, 2);
	select_ROI(j);
	run("Enlarge...", "enlarge=" + delta);
//	run("Analyze Particles...", "size=0-" + size_MAX + " circularity=0.50-1.00 show=Overlay display clear overlay exclude");
	run("Analyze Particles...", "size=4-" + size_MAX + " circularity=0.50-1.00 show=Overlay display clear overlay");
	return newArray(nResults, nResults/PM_length);
}

setBatchMode(false);