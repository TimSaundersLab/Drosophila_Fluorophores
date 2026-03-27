/*  This macro was used to analyse the fluorescence intensity of early stage
 *  embryos. It was used on TIFF files that resulted from the conversion of
 *  the original .vsi files into that format. Since all the required files 
 *  were grouped in a single folder, lines 18 and 19 of the macro were 
 *  omitted.
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

processFolder(input);

function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		//if(File.isDirectory(input + File.separator + list[i]))
			//processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

function processFile(input, output, file) {
	print("Processing: " + input + File.separator + file);
	run("Bio-Formats Importer", "open=[" + input + File.separator + file + "] color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT z_begin=14 z_end=41 z_step=1");
	b = File.nameWithoutExtension;
	OriginalImage = getTitle();
	run("Duplicate...", "duplicate");

	run("Gaussian Blur...", "sigma=4 stack");
	run("Subtract Background...", "rolling=50 stack");
	setAutoThreshold("Otsu dark");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark calculate");
	
	run("Set Measurements...", "area mean standard modal min shape median stack display redirect=["+OriginalImage+"] decimal=3");
	run("Watershed", "stack");
	
	while (selectionType() != 3
) {
		waitForUser("Draw an ellipse with mayor axis = 140 um and minor axis = 56 um\n"
		+"surrounding the nuclei in the center of the embryo,\n"
		+"then clik OK\n");
}
	
	roiManager("add");
	roiManager("Save", output + File.separator + b +"_ellipse_ROI.zip");
		
	run("Analyze Particles...", "size=4.3-51 circularity=0.68-1.00 display exclude clear include add stack");
	
	waitForUser("Please remove unwanted segmented objects.");
	
	run("Clear Results");
	roiManager("measure");
	print("Saving Results to: " + output);
	saveAs("results", output + File.separator + b +"_Results.csv");
	
	print("Saving Mean distribution to: " + output);
	run("Distribution...", "parameter=Mean automatic");
	saveAs("tiff", output + File.separator + b +"_MeanDistributionImage.tif");
	
	Plot.getValues(binStart, count);
 	Table.showArrays(b+"_Table(indexes)", binStart, count);
 	Table.save(output + File.separator + b +"_MeanDistributionValues.csv");
 	run("Close");
 	
	print("Saving ROIs to: " + output);
	roiManager("Show All without labels");
	roiManager("Show None");
	roiManager("Save", output + File.separator + b +"_ROIs.zip");
	close("Roi Manager");
	
	close("*");
}
print("Finished! ");
