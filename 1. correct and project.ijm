setBatchMode(true); // starts batch mode
var extension_list = newArray("czi", "oif", "lif", "vsi"); // only files with these extensions will be processed
var projection_type = newArray("none", "MAX", "SUM", "both");
var boolean = newArray("no", "yes");
image_name = "image";
count = 0;
n = 0;
dir_type = "-raw/";

close("*");
close("Log");
close("Results");
if(isOpen("Status"))
	print("[Status]","\\Close");

Dialog.create("Correct drift and bleach, calculate projection"); // Creates dialog window with the name "Batch export"
	Dialog.addDirectory("Directory:", "");	// Asks for directory to be processed. Copy paste your complete path here
	Dialog.addChoice("Correct bleaching (histogram matching method):", boolean);
	Dialog.addChoice("Projection:", projection_type);
	Dialog.show();
	dir = Dialog.getString();
	bleach_correct = Dialog.getChoice;
	projection = Dialog.getChoice();

run("Text Window...", "name=[Status] width=100 height=3");
countFiles(dir);
processFolder(dir);

function processFolder(dir) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/"))
			processFolder(""+dir+list[i]);
		else {
			if (endsWith(dir, dir_type)){
				showProgress(n++, count);
				q = dir+list[i];
				extIndex = lastIndexOf(q, ".");
				ext = substring(q, extIndex+1);
				if (contains(extension_list, ext)) {
					getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
					print("[Status]", "Processing: " + n + "/" + count +" - " + list[i] + " (" + String.pad(hour,2) + ":" + String.pad(minute,2) + ":" + String.pad(second,2) + ")\n");
					processFile(q);
				}
			}
		}
	}
}

function processFile(q) {
	projectionsDir = File.getParent(dir)+"/"+replace(File.getName(dir), "-raw", "-projections")+"/";
	dataDir = File.getParent(dir)+"/"+replace(File.getName(dir), "-raw", "")+"/";
	if (!File.exists(dataDir))
		File.makeDirectory(dataDir);
	if (!File.exists(processedDir))
		File.makeDirectory(processedDir);
	open(q);
	rename(image_name);
	getDimensions(width, height, channels, slices, frames);
	for (s = channels*slices; s >= 1; s--){
		setSlice(s);
		run("Clear Results");
		run("Measure");
		MAX = getResult("Max", 0);
			if (MAX == 0){
				run("Delete Slice", "delete=slice");
				for (c = 1; c < channels; c++)
					s--;
			} else
				break;
	}
	run("Split Channels");
//	y = nImages;
	for (j = 1; j <= channels; j++) {
//		selectImage(j);
		selectImage("C"+j+"-"+image_name);
		run("StackReg", "transformation=Translation");
		autocrop(j);
		if (bleach_correct == "yes"){
			selectWindow("C"+j+"-"+image_name);
			if (slices*channels > 1) run("Bleach Correction", "correction=[Histogram Matching]"); //creates a duplicate image with "DUP_" prefix
			close("C"+j+"-"+image_name);
			selectWindow("DUP_C"+j+"-"+image_name);
			rename("C"+j+"-"+image_name);
		}
	}
	run("Merge Channels...", "c1=[C1-image] c2=[C2-image] create"); //this merges the channel in a way that red is ch1 and green is ch2
	saveAs("TIFF", dataDir + list[i] + "-processed");
	rename("merged");

	if (projection == "SUM" || projection == "both"){
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Sum Slices]");
		saveAs("TIFF", projectionsDir + list[i] + "-SUM");
		close();
	}
	if (projection == "MAX" || projection == "both"){
		selectWindow("merged");
		run("Duplicate...", "duplicate");
		run("Z Project...", "projection=[Max Intensity]");
		saveAs("TIFF", projectionsDir + list[i] + "-MAX");
		close();
	}
	close("*");
}

function autocrop(j) {
	selectImage("C"+j+"-"+image_name);
	run("Z Project...", "projection=[Min Intensity]");
	rename("MIN_project");
	for (k = 1; k >= 0; k--) {
		selectWindow("MIN_project");
		doWand(k*(width-1), k*(height-1));
		run("Clear Results");
		run("Measure");
		MIN = getResult("Min", 0);
		if (MIN == 0) {
			selectImage("C"+j+"-"+image_name);
			run("Restore Selection");
			run("Make Inverse");
			run("Crop");
		}
	}
}

function contains(array, value) {
    for (i=0; i<array.length; i++)
        if (array[i] == value) return true;
    return false;
}

function countFiles(dir) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/"))
			countFiles(""+dir+list[i]);
		else {
			q = dir+list[i];
			extIndex = lastIndexOf(q, ".");
			ext = substring(q, extIndex+1);
			if (contains(extension_list, ext) && endsWith(dir, dir_type)) count++;
		}
	}
}

close("Log");
close("Results");
print("[Status]","\\Close");
setBatchMode(false);
waitForUser("Finito! All images were processed sucessfully.");