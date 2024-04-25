var border = 0.3; //value needs to be adjusted based on actual microscopy images
var title = "";
var width = 0;
var height = 0;
var channels = 0;
var pixelWidth = 0;
var pixelHeight = 0;
var roiDir = "";
var excludeDir = "";
var MasksDir = "";
var dirType = "";
var count = 0;
var counter = 1;
var RoiSet_count = 0;
var filecount = 0;

var RoiSet_suffix = "-RoiSet.zip";
var files_with_ROIs = "";
var overwrite = 1;
var exclude = false;
var jump = 0;
var extension_list = newArray("czi", "oif", "lif", "tif", "vsi");
var processes = newArray("Convert Masks to ROIs", "Check ROIs");
var image_types = newArray("transversal", "tangential");
var dummy_name = "Image name hidden";
boolean = newArray("yes","no");

help = "<html>"
	+"<b>Directory</b><br>"
	+"Specify the directory where you want <i>Fiji</i> to start looking for folders with images. "
	+"The macro works <u>recursively</u>, i.e., it looks into all subfolders. All folders with names <u>ending</u> with the word \"<i>data</i>\" "
	+"(for <i>transversal</i> image type) or \"<i>data-caps</i>\" (for <i>tangential</i> image type) are processed. "
	+"All other folders are ignored.<br>"
	+"<br>"
	+"<b>Subset</b> <i>(optional)</i><br>"
	+"If used, only images with filenames containing specified <i>string</i> will be processes. This option can be used to selectively process images of a specific strain, condition, etc. "
	+"Leave empty to process all images in specified directory.<br>"
	+"<br>"
	+"<b>Channel(s)</b><br>"
	+"Specify channel to be used for processing. The macro needs to be run separately for individual channels. "
	+"Selection of multiple channels (comma separated, no space) and range (with the use of dash) are supported. <br>"
	+"<br>"
	+"<b>Image type</b><br>"
	+"Select if your images represent <i>transversal</i> (also called <i>equatorial</i>) or <i>tangential</i> sections of the cells.<br>"
	+"<br>"
	+"<b>Process</b><br>"
	+"&#8226; <i>Convert Masks to ROIs</i> - select if you want to create ROIs from <i>Masks</i> created by <i>Cellpose</i> (or another software).<br>"
	+"&#8226; <i>Check ROIs</i> - select if you want to check the accuracy of ROIs created by <i>Convert Masks to ROIs</i>.<br>"
	+"<br>"
	+"<b>Convert ROIs to ellipses</b><br>"
	+"The transversal sections of budding yeast cells can be approximates with ellipses, which makes it easier to change their size and shape. "
	+"This option is not recommended for other cell types.<br>"
	+"<br>"
	+"<b>Blind experimenter</b><br>"
	+"Randomizes the order in which images are shown to the experimenter and hides their names (metadata are not changed). "
	+"Also hides information about the parent folder in the <i>ROI adjust</i> dialog window.<br>"
	+"<br>"
	+"</html>";

Dialog.create("Select experiment directory, process and image type");
	Dialog.addDirectory("Directory:", "D:/Yeast/EXPERIMENTAL/microscopy/JZ-M-064-230413 - Candida - test-whole_frame/");
	Dialog.addString("Subset (optional):", "");
	Dialog.addNumber("Channel:", 1);
	Dialog.addChoice("Image type:", image_types);
	Dialog.addChoice("Process:", processes);
	Dialog.addChoice("Convert ROIs to ellipses (e.g., for budding yeast)", boolean, "yes");
	Dialog.addChoice("Blind experimenter", boolean, "no");
	Dialog.addChoice("Save preview ROIs (tangential only)", boolean, "no");
	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
	Dialog.addHelp(help);
	Dialog.show();
	dir = replace(Dialog.getString(), "\\", "/");
	subset = Dialog.getString();
	ch = Dialog.getNumber();
	image_type = Dialog.getChoice();
	process = Dialog.getChoice();
	ellipses = Dialog.getChoice();
	blind = Dialog.getChoice();
	save_preview = Dialog.getChoice();

initialize();

if (matches(process, "Convert Masks to ROIs")){
	setBatchMode(true);
	countRoiSetFiles(dir, true);
	if (isOpen("Log") && RoiSet_count > 0){
		files_with_ROIs = getInfo("Log");
		if (getBoolean("WARNING!\n"+RoiSet_count+ " of "+ count +" images already have defined sets of ROIs (listed in the Log window).\nDo you wish to overwrite the existing ROI sets?") == 0){
			overwrite = 0;
			count = count - RoiSet_count;
		}
	}
	run("Text Window...", "name=[Status] width=40 height=2");
	close("Log");
} else {
	countRoiSetFiles(dir, false);
	if (RoiSet_count > 0)
		if (getBoolean("WARNING!\n"+RoiSet_count+" images do not have defined sets of ROIs (listed in the Log window).\nDo you wish to continue?") == 0)
			exit("Macro terminated by the user.");
	count = count - RoiSet_count;
	html_ROIs = "<html>"
	+"The lines defining the edges of ROIs need to be placed:<br>"
	+"&#8226; in the <b>middle</b> of the plasma membrane for <b>plasma membrane proteins</b> (Fig. 1)<br>"
	+"&#8226; on the <b>edge</b> of visible cell for <b>cytoplasmic proteins</b> (Fig. 2)<br>"
	+"<br>"
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.1.png?raw=true\" alt=\"Fig 1\" width=256 height=256> <b>Fig. 1</b> "
	+"<img src=\"https://raw.githubusercontent.com/jakubzahumensky/testing/main/Fig.2.png?raw=true\" alt=\"Fig 2\" width=256 height=256> <b>Fig. 2</b> "
	+"<br>"
	+"<i>ROIs deviating from these guidelines will result in incorrect quantification.</i><br>"
	+"</html>";		
	showMessage("Important note on ROI placement", html_ROIs);
}

processFolder(dir);

//Definition of "processFolder" function: starts in selected directory, makes a list of what is inside then goes through it one by one
//If it finds another directory, it enters it and makes a new list and does the same.
//In this way, it enters all subdirectories and looks for data.
function initialize(){
	if (matches(image_type, "tangential"))
		dirType = "data-caps";
	else
		dirType = "data";
	//dirType = "data-"+image_type+"/";
//	ROIdirType = replace(dirType, "data", "ROIs");
	run("Set Measurements...", "area mean min standard modal bounding centroid fit shape redirect=None decimal=5");
	countFiles(dir);
	if (count == 0)
		exit("There are no images to process. Check that the appropriate 'Image type' was selected and that the used file structure is correct.");
	if (isOpen("Status"))
		print("[Status]","\\Close");
	if (isOpen("Log"))
		close("Log");
	close("*");
}	

function processFolder(dir) {
	list = getFileList(dir);
	if (blind == "yes")
		list = randomize(list);
	for (i = 0; i < list.length; i++) {
		showProgress(i+1, list.length);
      	if (endsWith(list[i], "/"))
      		processFolder("" + dir + list[i]);
      	else {
			file = dir + list[i];
			if (File.exists(file)){
				if (indexOf(file, subset) >= 0 && endsWith(dir, dirType+"/")) {
					extIndex = lastIndexOf(file, ".");
					ext = substring(file, extIndex+1);
					if (contains(extension_list, ext)) {
						title = File.getNameWithoutExtension(file);
						if (matches(process, "Convert Masks to ROIs")) {
							if ((overwrite == 1) || ((overwrite == 0) && indexOf(files_with_ROIs, dir + title) < 0)){
								print("[Status]", "\\Update:" + "Processing: " + counter + "/" + count);
								Map_to_ROIs();
							}
						}
						else
						i = ROI_check(i);
					}
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
			file = dir + list[i];
			if (indexOf(file, subset) >= 0 && endsWith(dir, dirType+"/")) {
				extIndex = lastIndexOf(file, ".");
				ext = substring(file, extIndex+1);
				if (contains(extension_list, ext)) 
					count++;
			}
		}
	}
}

function countRoiSetFiles(dir, boo) {
	list = getFileList(dir);
	for (i = 0; i < list.length; i++) {
		if (endsWith(list[i], "/"))
			countRoiSetFiles("" + dir + list[i], boo);
		else {
			file = dir + list[i];
			if (indexOf(file, subset) >= 0 && endsWith(dir, dirType+"/")) {
				extIndex = lastIndexOf(file, ".");
				ext = substring(file, extIndex+1);
				if (contains(extension_list, ext)) {
//					roiDir = replace(dir, "data", "ROIs");
//					roiDir = File.getParent(dir)+"/ROIs/";
					roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
					title = File.getNameWithoutExtension(file);
					if (File.exists(roiDir + title + RoiSet_suffix) == boo){
						RoiSet_count++;
						print(file);
					}
				}
			}
		}
	}
}

function contains(array, value) {
    for (i = 0; i < array.length; i++) 
        if (array[i] == value) return true;
    return false;
}

function randomize(array) {
	new_array = newArray(array.length);
	control_array = newArray(array.length);
	for (i = 0; i < array.length; i++) {
	  	n = array.length;
	    while (contains(control_array, n))
	    	n = floor(array.length*random);
	    control_array[i] = n;
	    new_array[i] = array[n-1];
	}
   return new_array;
}

//Preparatory step where image suffix (extension) is removed from filename. This makes the steps below simpler and more universal.
function prep() {
	open(file);
//	run("Bio-Formats Windowless Importer", "open=[file]");
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
   	if (channels >= ch)
		Stack.setChannel(ch);
	Stack.setDisplayMode("color");
	rename(list[i]);
	dummy_name = i;
}

//conversion of the LabelMap masks made in Cellpose to ROIs; macro calls the "LabelMap to ROI Manager (2D)" that is part of the SCF plugin package (available at: https://sites.imagej.net/SCF-MPI-CBG/plugins/)
function Map_to_ROIs() {
//	MasksDir = replace(dir, "data", "Masks");
//	MasksDir = File.getParent(dir)+"/Masks/";
	MasksDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "Masks")+"/";
	if (File.exists(MasksDir + title + "_cp_masks.png")){
		prep(); //Map_to_ROIs calls the prep() function
//		roiDir = replace(dir, "data", "ROIs");
//		roiDir = File.getParent(dir)+"/ROIs/";
		roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
		if (!File.exists(roiDir)) 
			File.makeDirectory(roiDir);
		run("Clear Results");
		run("Measure");
		open(MasksDir + title + "_cp_masks.png");
		roiManager("reset"); // clear ROI manager of anything that might be there from previous work
		run("LabelMap to ROI Manager (2D)");  // for each cell in the Cellpose map a ROI is made and put into ROI manager
		selectWindow(list[i]);
		numROIs = roiManager("count"); // find out how many ROIs (i.e., cells we have in the ROI manager)
	//Cleaning of ROIs:
	//go through all ROIs in the manager one by one, analyze their position, size and CV of fluorescence
	//if ROIs are too close to edges of image (incomplete cells), if they are too small or dead (based on CV measurement), remove the respective ROI from the ROI manager
	//the loop goes backwards because deleting/adding of ROIs changes the ID number of those with higher ID numbers. When counting backwards, these have already been processed when changes are made.
		if (numROIs > 0) {
			for (j = numROIs-1; j >= 0 ; j--) {
				run("Clear Results");
				roiManager("Select", j);
				run("Measure");
				Mean = getResult("Mean", 0);
				Min = getResult("Min", 0);
				SD = getResult("StdDev", 0);
				ROI_width = getResult("Width", 0);
				ROI_height = getResult("Height", 0);
				ROI_origin_x = getResult("BX", 0); //upper left corner
				ROI_origin_y = getResult("BY", 0);
				ROI_circularity = getResultString("Circ.", 0);
				too_left = ROI_origin_x < border; //1 for a ROI too close to the left image edge
				too_high = ROI_origin_y < border; //1 for a ROI too close to the upper image edge
				too_right = ((ROI_origin_x + ROI_width) > (width*pixelWidth - border)); //1 for a ROI too close to the right image edge
				too_low = ((ROI_origin_y + ROI_height) > (height*pixelHeight - border));//1 for a ROI too close to the lower image edge
				too_irregular = (ROI_circularity < 0.8);
				if ((too_right + too_left + too_high + too_low > 0) || (too_irregular && ellipses == "yes"))// if the ROI is too close to any of the edges, remove
					roiManager("Delete"); //if at least one of the listed conditions is TRUE (has value 1), the respective ROI is deleted
				else {
					if (ellipses == "yes")
						run("Fit Ellipse");
					else {
						run("Enlarge...", "enlarge=" + pixelWidth);
						run("Enlarge...", "enlarge=-" + pixelWidth); //this enables the circumference of the selection to be converted to a line
					}
				//create a new selection that is added to the ROI manager and remove the original one
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}												
			}
			roiManager("Remove Channel Info");
	        roiManager("Remove Slice Info");
			roiManager("Remove Frame Info");
			numROIs = roiManager("count");
		}
		if (numROIs == 0) {
			makeRectangle(0, 0, 100, 100);
			roiManager("Add");
		}
			roiManager("Save", roiDir + title + RoiSet_suffix); //save the updated list of ROIs 
			close("*");
	counter++;
	} else
		print(file);
}

//function ROI_check() opens each raw file in the analysis folder and loads the ROIs made by the Map_to_ROIs() function.
//It then allows the user to check the exiting ROIs, adjust/remove them, or add additional ones.
//Option to enlarge/shrink size of all ROIs is implemented. For shrinking input negative values.
function ROI_check(k) {
//	roiDir = replace(dir, "data", "ROIs");
//	roiDir = File.getParent(dir)+"/ROIs/";
	roiDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs")+"/";
	if (File.exists(roiDir + title + RoiSet_suffix)){
		prep();
//		excludeDir = replace(dir, "data", "data-exclude");
//		excludeDir = File.getParent(dir)+"/exclude/";
		excludeDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "data-exclude")+"/";
		if (blind == "yes")
			rename(dummy_name);
		window = getTitle();
		parent = File.getParent(dir);
		dir_name = File.getName(dir);
		parent_name = File.getName(parent);
		roiManager("reset");
		roiManager("Open", roiDir + title + RoiSet_suffix);
		numROIs = roiManager("count");
		selectWindow(window);
		run("gem");
		run("Invert LUT");
		roiManager("Show All with labels");
		roiManager("Set Color", "cyan");
		run("Enhance Contrast", "saturated=0.05");
		run("Maximize");
		setTool("ellipse");
	
		html = "<html>"
			+"The user can move, delete, add ROIs (regions of interest) and change their size and shape. All ROIs need to be elliptical (the elliptical tool is preselected). "
			+"To add new ROIs first make an ellipse and then press the \"<i>Add</i>\" button in the ROI manager window or the \"<i>t</i>\" key on the keyboard.<br>"
			+"<b>Note: All changes are automatically saved when \"OK\" is pressed.</b><br>"
			+"<br>"
			+"<b>Stats:</b><br>"
			+"&#8226; <i>folder</i> - current working directory in which images are being processed (hidden when <i>Blind experimenter</i> option is used)<br>"
			+"&#8226; <i>image counter</i> - current image/number of images in <i>folder</i><br>"
			+"<br>"
			+"<b>Enlarge all ROIs</b><br>"
			+"This option allows the user to make all ROIs larger by a specified number of pixels in each direction (values as low as 0.5 have an effect). "
			+"Use negative values to make the ROIs smaller. Leave at 0 if you desire no change to be made. "
			+"When a nonzero value is inserted the ROI size is adjusted and can be checked and changed again. The processing does not continue to the next image until 0 is used.<br>"
			+"<br>"
			+"<b>Return to previous image</b><br>"
			+"Select if you desire to go back to the previous image. This option only works within the current folder displayed in the stats window.<br>"
			+"<br>"
			+"<b>Note on ROI placement</b><br>"
			+html_ROIs;
		
		delta = 1;
		shift_x = 0;
		shift_y = 0;										
		while ((delta != 0) || (shift_x != 0) || (shift_y != 0)) { //as long as any of resize and shift parameters are non-zero, show the dialog window
			Dialog.createNonBlocking("Check and adjust ROIs");
			if (blind == "yes") {
				dir_name = "hidden";
				parent_name = dir_name;
			}
			Dialog.addMessage("Stats:\nfolder: \"" + parent_name + "/" + dir_name + "\"" + "\nimage counter: " + i+1 + "/" + list.length + " (" + counter + "/" + count +" total)", 14);
			Dialog.addMessage("Adjust all " + numROIs + " ROIs", 12);
			Dialog.addNumber("Enlarge (neg. values shrink):", 0, 0, 2, "px");
			Dialog.addNumber("Move right (neg. values move left)", 0, 0, 2, "px");
			Dialog.addNumber("Move down (neg. values move up)", 0, 0, 2, "px");
		   	Dialog.addNumber("Jump forward by (beg. values jump back)", 0, 0, 2, "images");
		   	Dialog.addCheckbox("Exclude current image from analysis", false);
		   	Dialog.addMessage("Click \"Help\" for more information on the parameters.");
		   	Dialog.setLocation(screenWidth*3.1/4,screenHeight/6);
		    Dialog.addHelp(html);
		    Dialog.show();
			delta = Dialog.getNumber();
			shift_x = Dialog.getNumber();
			shift_y = Dialog.getNumber();
			jump = Dialog.getNumber();
			exclude = Dialog.getCheckbox();
			
			if (exclude == true) {
				if (!File.exists(excludeDir))
					File.makeDirectory(excludeDir);						
				File.rename(dir + list[k], excludeDir + list[k]);
				close("Log");
			}
					
			roiManager("deselect");
			roiManager ("translate", shift_x, shift_y);		
			if (delta != 0) {
				numROIs = roiManager("count");
				for(j = numROIs-1; j >= 0 ; j--) {
					roiManager("Select", j);
					if (delta == -0.5){
						run("Enlarge...", "enlarge=-" + pixelWidth);
						run("Enlarge...", "enlarge=" + 0.5*pixelWidth);
					} else 
						run("Enlarge...", "enlarge=" + delta*pixelWidth);
					if (ellipses == "yes")
						run("Fit Ellipse");
					roiManager("add");
					roiManager("Select", j);
					roiManager("Delete");
				}
			}
		}
		roiManager("Remove Channel Info");
	    roiManager("Remove Slice Info");
		roiManager("Remove Frame Info");
		roiManager("Save", roiDir + title + RoiSet_suffix);
		if (save_preview == "yes")
			ROI_preview();
		close("*");
		counter++;
		k = jump_around(jump);
	}
	return k;
}

function ROI_preview() {
	//roi_previewDir = replace(dir, "data", "ROIs_preview");
	roi_previewDir = File.getParent(dir)+"/"+replace(File.getName(dir), "data", "ROIs_preview")+"/";
	if (!File.exists(roi_previewDir))
		File.makeDirectory(roi_previewDir);
	numROIs = roiManager("count");
	run("gem");
	run("Invert LUT");
	roiManager("Show All without labels");
	numROIs = roiManager("count");
	for(j = numROIs-1; j >= 0 ; j--) {
		roiManager("Select", j);
		run("Clear Results");
		run("Measure");
		major_axis = getResult("Major", 0);
		delta = major_axis/2*(1-sqrt(2/3));
		run("Enlarge...", "enlarge=-" + delta);
		run("Fit Ellipse");
		roiManager("add");
	}
	title = getTitle();
	save_name = list[i];
	if (blind == "yes")
		save_name = i;
	saveAs("TIFF", roi_previewDir + save_name + "ROIs_preview");
}

function jump_around(jump_by){
	if (jump_by > 0){
		if (k + jump_by < list.length){
			counter = counter-1+jump_by;
			k = k-1+jump_by;
		} else {
			counter = counter+list.length-k-2;
			k = list.length-2;
		}
	}
	if (jump_by < 0){
		if (k + jump_by < 0) {
			counter = counter-k-1;
			k = -1;
		}
		if (k > 0)
			if (File.exists(dir + list[k + jump_by])){
				k = k - 1 + jump_by;
				counter = counter - 1 + jump_by;
			} else {
//				waitForUser("Cannot go back, the image has been moved to the 'exclude' folder.");
				k = k - 3 + jump_by;
				counter = counter - 1 + jump_by;
//				k = k - 1;
			}
	}
	return k;
}


//close Results table and ROI manager
close("Results");
close("ROI manager");
if (matches(process, "Convert Masks to ROIs")){
	print("[Status]", "\\Close");
	if (counter-1 < count)
		waitForUser("This is curios...", "ROI sets have not been made for " + count-counter+1 + " out of "+ count + " images (listed in the Log window).\n"
		+"Check if you have made segmentation masks for all images and if the data structure is correct before running the macro again.");
	else
		waitForUser("Finito!", "ROI sets for all images were made successfully.");
} else
	waitForUser("Finito!", "All existing ROIs checked and adjusted.");
setBatchMode(false); //exits batch mode (only activated for conversion of Maps to ROIs)