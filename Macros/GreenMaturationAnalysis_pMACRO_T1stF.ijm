/* Lines 16 and 17 of the macro were omitted because all required files were
 *  grouped in a single folder.
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix
#@ String (label = "Time interval for inputs", value = 1) TimeInterval

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
	run("Bio-Formats Importer", "open=[" + input + File.separator + file + "] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
	Stack.getDimensions(width, height, channels, slices, frames);
	close();
	Dialog.create("True first frame selection");
	Dialog.addNumber("Which frame is the true first frame?", 1);
	Dialog.show();
	True1stFrame = Dialog.getNumber();
	run("Bio-Formats Importer", "open=[" + input + File.separator + file + "] color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT c_begin=2 c_end=2 c_step=1 z_begin=2 z_end=7 z_step=1 t_begin=" + True1stFrame + " t_end=" + frames + " t_step=1");
	b = File.nameWithoutExtension;
	OriginalImage = getTitle();

	run("Duplicate...", "duplicate");

	run("Gaussian Blur...", "sigma=2 stack");
	run("Subtract Background...", "rolling=50 stack");
	roiManager("open", output + File.separator + b + "_ellipse_ROI.zip");
    roiManager("select", 0);
	close("Roi Manager");
	Stack.setFrame(frames);
	setAutoThreshold("Li dark stack");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Li background=Dark calculate");
	run("Watershed", "stack");
	
	run("Set Measurements...", "area mean standard modal min shape median stack display redirect=[" + OriginalImage + "] decimal=3");

	while (selectionType() != 3) {
		waitForUser("Draw an ellipse with mayor axis = 140 um and minor axis = 56 um\n"
		+"surrounding the nuclei in the center of the embryo,\n"
		+"then clik OK\n");
	}
			
	roiManager("add");
	roiManager("Save", output + File.separator + b + "_ellipse_ROI.zip");
	close("Roi Manager");		


	run("Analyze Particles...", "size=4.30-51.00 circularity=0.40-1.00 display exclude clear include summarize add stack");
	
	Table.save(output + File.separator + b + "_Summary_Table.csv");
	run("Close");
	
	waitForUser("Please remove unwanted segmented objects.");
	
	run("Clear Results");
	roiManager("measure");
	print("Saving Results to: " + output);
	saveAs("results", output + File.separator + b + "_Results.csv");
	
	MeansPerFrame = newArray();
	StdDevPerFrame = newArray();
	NoOfObjectsPerFrame = newArray();
	for (i = 1; i <= frames; i++) {
		ObjectsMeansAtThisFrame = newArray();
		for (j = 0; j < nResults; j++) {
			Frame = getResult("Frame", j);
			MeanFluorescence = getResult("Mean", j);
			if (Frame == i) {
				ObjectsMeansAtThisFrame = Array.concat(ObjectsMeansAtThisFrame,MeanFluorescence);
			}
		}
		 Table.showArrays("Means at this frame", ObjectsMeansAtThisFrame);
		 NoOfObjectsAtThisFrame = Table.size;
		 NoOfObjectsPerFrame = Array.concat(NoOfObjectsPerFrame,NoOfObjectsAtThisFrame);
		 selectWindow("Means at this frame");
		 run("Close");
		Array.getStatistics(ObjectsMeansAtThisFrame, Fmin, Fmax, Fmean, FstdDev);
		MeansPerFrame = Array.concat(MeansPerFrame,Fmean);
		StdDevPerFrame = Array.concat(StdDevPerFrame,FstdDev);
	}
	 Table.showArrays("Mean fluorescence per frame(indexes)", MeansPerFrame, StdDevPerFrame, NoOfObjectsPerFrame);
	 Table.save(output + File.separator + b + "_MFpF.csv");//MFpF stands for "Mean fluorescence per frame".
	
	FramesOnTable = Table.size;
	Table.renameColumn("Index", "Time");
	for (i = 0; i < FramesOnTable; i++) {
		Table.set("Time", i, Table.get("Time", i) * TimeInterval);
	}
	Table.update;
	
	Plot.create(b + "_Plot", "Time", "Mean");
	Plot.add("Line", Table.getColumn("Time"), Table.getColumn("MeansPerFrame"));
	Plot.add("error bars", Table.getColumn("StdDevPerFrame"));
	Plot.setStyle(0, "blue,#a0a0ff,1.0,Line");
	Plot.show();
	saveAs("tiff", output + File.separator + b + "_Plot.tif");
	
	Plot.getValues(Time, Mean);
 	Table.showArrays(b + "_Plot_Values", Time, Mean);
 	Table.save(output + File.separator + b + "_Plot_Values.csv");
	run("Close");
	selectWindow("Mean fluorescence per frame");
	run("Close");
	 	 	
	print("Saving ROIs to: " + output);
	roiManager("Show All without labels");
	roiManager("Show None");
	roiManager("Save", output + File.separator + b + "_ROIs.zip");
	close("Roi Manager");
	
	close("*");
}
selectWindow("Results");
run("Close");
print("Finished!");