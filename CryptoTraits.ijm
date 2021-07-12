//// CryptoTraits: an ImageJ macro to measure morphological traits from side-view images of cryptobenthic fishes
//// Author: Mattia Ghilardi
//// mattia.ghilardi@leibniz-zmt.de
//// Last updated: 21 May 2021

////////////////////////////////////////////////////////////////////////////////////////////////////

var v = versionCheck();

////////////////////////////////////////  FUNCTIONS  ///////////////////////////////////////////////

// "versionCheck": check version at install time
function versionCheck() {
    requires("1.53e");
    return 1;
}

// "iArr": Get index of a specific element in an array
function iArr(a, value) {
	for (i = 0; i < a.length; i++) {
		if (a[i] == value) {
			return i;
		}
	}
	return -1; // if the selected value is not in the array returns -1
}

// "imageSize": Get image's width and height and the center's coordinates
var h, w, ymid, xmid;
function imageSize() {
		h = getHeight();
		w = getWidth();
		ymid = h/2;
		xmid = w/2;
}

// "orientation": Get fish orientation
var side;
function orientation() {
	// Orientation
	Dialog.create("Orientation");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Which side is the fish facing?");
	Dialog.setInsets(5, 25, 5);
	Dialog.addChoice("", newArray("left", "right"));
	Dialog.show();
	side = Dialog.getChoice();
}

// "setScale": Set scale
var pw;
function setScale() {
	setTool("Line");
	run("Line Width...", "line=1");
	waitForUser("Set scale", "Trace a line on a reference \nobject of known length.");
	if (selectionType != 5) {
		showMessage("Straight line selection required!");
		waitForUser("Set scale", "Trace a line on a reference \nobject of known length.");
	}
	roiManager("Add");
	Dialog.create("Set scale");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Please enter the known length \nand select the unit of measurement.\nAny unit will be converted to 'cm'.");
	Dialog.setInsets(5, 15, 5);
	Dialog.addNumber("Known length:", 0);
	Dialog.setInsets(5, 15, 5);
	Dialog.addChoice("Unit:", newArray("mm", "cm", "inch"));
	Dialog.show();
	num = Dialog.getNumber();
	unit = Dialog.getChoice();
	num1 = num/10;
	num2 = num*2.54;
	if (unit == "cm") {
		run("Set Scale...", "known=num unit=cm");
	} else if  (unit == "mm") {
		run("Set Scale...", "known=num1 unit=cm");
	} else {
		run("Set Scale...", "known=num2 unit=cm");
	}
	getPixelSize(unit, pw, ph);
	roiManager("Select", 0);
	roiManager("Rename", "px/"+unit);
	run("Select None");
}

// "misureAngle": Misure angle in degrees between a line and the horizontal axis.
function misureAngle(x1, y1, x2, y2) {
	dx = x2-x1;
	dy = y1-y2;
	angle = (180.0/PI)*atan(dy/dx);
	return angle;
}

// "rotateImage": Rotate an image based on the angle of a straight line selection.
function rotateImage(x1, y1, x2, y2) {
	angle = misureAngle(x1, y1, x2, y2);
	run("Arbitrarily...", "angle="+angle+" interpolate fill");
}

// "straightenRotate": Adjust the image if the fish is bended or not horizontal
var straighten, rotate, straightened;
function straightenRotate() {
	Dialog.create("Image adjustment");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("The fish must be straight and horizontal.\nIf this is not the case check the box with the\nrequired action, otherwise press OK.");
	Dialog.setInsets(5, 70, 0);
	Dialog.addCheckbox("Straighten", false);
	Dialog.setInsets(5, 70, 0);
	Dialog.addCheckbox("Rotate", false);
	Dialog.show();
	
	straighten = Dialog.getCheckbox();
	rotate = Dialog.getCheckbox();
	
	if (straighten == 1) {
		setTool("Polyline");
		run("Line Width... ");
		waitForUser("Straighten fish", "Create a segmented line selection following the midline of the fish.\nThe selection must extend from both the snout and caudal fin.\n \nAdjust the selection as needed, then increase the line width\nuntil the whole fish falls within the shaded area.\n \nWhen finished, close the 'Line Width' window and press OK.");
		if (selectionType != 6) {
			showMessage("Segmented line selection required!");
			waitForUser("Straighten fish", "Create a segmented line selection following the midline of the fish.\nThe selection must extend from both the snout and caudal fin.\n \nAdjust the selection as needed, then increase the line width\nuntil the whole fish falls within the shaded area.\n \nWhen finished, close the 'Line Width' window and press OK.");
		}
		run("Straighten...");
		straightened = getImageID();
		rename(title);
		selectImage(copy);
		run("Close");
		run("Line Width...", "line=1"); 
	} 
	else if (straighten == 0 && rotate == 1) {
		setTool("Line");
		waitForUser("Rotate image", "Trace a straight line with the same orientation as the fish. \nThe image will be rotated based on the angle of the line selection.");
		if (selectionType != 5) {
			showMessage("Straight line selection required!");
			waitForUser("Rotate image", "Trace a straight line with the same orientation as the fish. \nThe image will be rotated based on the angle of the line selection.");
		}
		getLine(x1, y1, x2, y2, lineWidth);
		rotateImage(x1, y1, x2, y2);
	}
}

// "roiAddRename": Add selection to ROI and rename
function roiAddRename(name) {
	roiManager("Add");
	nROI = RoiManager.size;
	roiManager("Select", nROI-1);
	roiManager("Rename", name);
	run("Labels...", "color=white font=12 show use draw bold");
}

// "roiIntersection": Intersection points between two ROIs of which the second is a straight line
// Modified from: https://forum.image.sc/t/how-to-get-xy-coordinate-of-selection-line-crossing-a-roi/6923/7
function slope(x1, y1, x2, y2) {
	return -(y1-y2)/(x1-x2);
}
function lengt(x1, y1, x2, y2) {
	return sqrt(pow(x1-x2, 2)+pow(y1-y2, 2));
}
function extrema(p) {
	for (i = 1; i < p.length; i++) {
		p[i-1] = abs(p[i]-p[i-1]);
            }
}
function intersection(xx, yy, s, p) {
	for (i = 0; i < 2; i++) {
		if (i > 0) { 
			sign = -1; 
		} else { 
			sign = 1; 
		}
		dx = sign*sqrt(pow(p[i], 2)/(1+pow(s, 2)));
		xx[i] += dx;
		if (s != 1/0) { 
			yy[i] -= s*dx; 
		} else { 
			yy[i] += sign*p[i]; 
		}
	}
}
function roiIntersection(a, b){
	roiManager("Select", a);
	run("Create Mask");
	roiManager("Select", b);
	if (selectionType != 5) {
		exit("Straight line selection required!");
	}
	getSelectionCoordinates(x, y);
	slp = slope(x[0], y[0], x[1], y[1]);
	len = lengt(x[0], y[0], x[1], y[1]);
	profile = getProfile();
	extrema(profile);
	profile = Array.findMaxima(profile, 0, 1);
	profile[1] = len-profile[1];
	intersection(x, y, slp, profile);
	point1 = newArray(x[0], y[0]);
	point2 = newArray(x[1], y[1]);
	points = Array.concat(point1, point2);
	close("Mask");
	return points;
}

//////////////////////////////////////////  MACRO  /////////////////////////////////////////////////

macro "CryptoTraits Action Tool - N44C333D00C777D01C666D02C222D03CccdD04CaafD05CaafD06CaafD07Cb7bD08Cb7bD09CaafD0aCaafD0bCaafD0cCaafD0dC66bD0eC55bD0fC99fD0gCaafD0hCaafD0iCaafD0jCc58D0kCb8dD0lCaafD0mCddfD0nC777D10CfffD11CdddD12C333D13CdddD14CfffD15CfffD16CfffD17Cf77D18Cf77D19CfffD1aCfffD1bCfffD1cC999D1dC222D1eC111D1fC99aD1gCfffD1hCfffD1iCfffD1jCf44D1kCfbbD1lCfffD1mCfffD1nC777D20CfffD21CdddD22C333D23CdddD24CfffD25CfffD26CfffD27Cf77D28Cf77D29CfffD2aCfffD2bCbbbD2cC622D2dCa55D2eCa44D2fC644D2gCeeeD2hCfffD2iCfffD2jCf44D2kCfbbD2lCfffD2mCfffD2nC777D30CaaaD31C666D32C222D33CdddD34CfffD35CfffD36CfffD37Cf77D38Cf77D39CfffD3aCfffD3bC988D3cCc33D3dCf55D3eCf44D3fC733D3gCdddD3hCfffD3iCfffD3jCf44D3kCfbbD3lCfffD3mCfffD3nC777D40CaaaD41C666D42C222D43CdddD44CfffD45CfffD46CfffD47Cf77D48Cf77D49CfffD4aCfffD4bC666D4cCcccD4dCfffD4eCeddD4fC555D4gCcccD4hCfffD4iCfffD4jCf44D4kCfbbD4lCfffD4mCfffD4nC777D50CfffD51CdddD52C333D53CdddD54CfffD55CfffD56CfffD57Cf77D58Cf77D59CfffD5aCeeeD5bC555D5cCeeeD5dCeeeD5eC666D5fC555D5gCbbbD5hCfffD5iCfffD5jCf44D5kCfbbD5lCfffD5mCfffD5nC777D60CfffD61CdddD62C333D63CdddD64CfffD65CfffD66CfffD67Cf77D68Cf77D69CfffD6aCdddD6bC555D6cCcccD6dC666D6eC777D6fC777D6gCaaaD6hCfffD6iCfffD6jCf44D6kCfbbD6lCfffD6mCfffD6nC777D70CbbbD71C777D72C222D73CccdD74CbbfD75CaafD76CaafD77Cc69D78Cc69D79CaafD7aC77cD7bC55aD7cC66bD7dC44aD7eC99eD7fC66bD7gC55aD7hCaafD7iCbafD7jCe24D7kCc8bD7lCaafD7mCddfD7nC777D80CaaaD81C555D82C222D83CdddD84CeefD85CeefD86CeefD87CfefD88CfefD89CddeD8aC446D8bCccdD8cCeefD8dCeefD8eCeefD8fCbbcD8gC667D8hCeefD8iCedfD8jCf44D8kCfabD8lCeefD8mCfffD8nC777D90CfffD91CdddD92C333D93CdddD94CfffD95CfffD96CfffD97CfffD98CfffD99CbbbD9aC666D9bCfffD9cCfffD9dCfffD9eCfffD9fCaaaD9gC555D9hCfffD9iCfffD9jCf44D9kCfbbD9lCfffD9mCfffD9nC777Da0CfffDa1CdddDa2C333Da3CdddDa4CfffDa5CfffDa6CfffDa7CfffDa8CfffDa9C888DaaC666DabCcaaDacCfaaDadCfaaDaeCfaaDafC533DagC444DahCfffDaiCfffDajCf44DakCfbbDalCfffDamCfffDanC777Db0CbbbDb1C888Db2C222Db3CdddDb4CfffDb5CfffDb6CfffDb7CfffDb8CfffDb9C777DbaDbbC844DbcCf55DbdCf55DbeCf44DbfC511DbgC444DbhCfffDbiCfffDbjCf44DbkCfbbDblCfffDbmCfffDbnC777Dc0C999Dc1C555Dc2C222Dc3CdddDc4CfffDc5CfffDc6CfffDc7CfffDc8CfffDc9CdddDcaC444DcbCcccDccCfffDcdCfffDceCfffDcfC777DcgC777DchCfffDciCfffDcjCf44DckCfbbDclCfffDcmCfffDcnC777Dd0CfffDd1CdddDd2C333Dd3CdddDd4CfffDd5CfffDd6CfffDd7CfffDd8CfffDd9CdddDdaC555DdbCfffDdcCfffDddCfffDdeCfffDdfCdddDdgC555DdhCeeeDdiCfffDdjCf44DdkCfbbDdlCfffDdmCfffDdnC777De0CfffDe1CdddDe2C333De3CdddDe4CfffDe5CfffDe6CfffDe7CfffDe8CfffDe9CdddDeaC555DebCfffDecCfffDedCfffDeeCfffDefCeeeDegC555DehCeeeDeiCfffDejCf44DekCfbbDelCfffDemCfffDenC777Df0CaaaDf1C666Df2C222Df3CdddDf4CfffDf5CfffDf6CfffDf7CfffDf8CfffDf9CeeeDfaC555DfbCcccDfcCfffDfdCfffDfeCeeeDffCaaaDfgC555DfhCeeeDfiCfffDfjCf44DfkCfbbDflCfffDfmCfffDfnC777Dg0CbbbDg1C777Dg2C222Dg3CdddDg4CfffDg5CfffDg6CfffDg7CfffDg8CfffDg9CfffDgaCaaaDgbC555DgcC777DgdCcccDgeCaaaDgfDggC666DghCfffDgiCfffDgjCf44DgkCfbbDglCfffDgmCfffDgnC777Dh0CfffDh1CdddDh2C333Dh3CccdDh4CbbfDh5CaafDh6CaafDh7CaafDh8CaafDh9CaafDhaCaafDhbC44aDhcC116DhdC77cDheC77cDhfC116DhgC88dDhhCaafDhiCaafDhjCd57DhkCb8dDhlCaafDhmCddfDhnC777Di0CfffDi1CdddDi2C333Di3CdddDi4CeefDi5CeefDi6CeefDi7CeefDi8CeefDi9CeefDiaCeefDibCddfDicC556DidCccdDieCccdDifC446DigCddeDihCeefDiiCeefDijCfefDikCeefDilCeefDimCfffDinC777Dj0CaaaDj1C666Dj2C222Dj3CdddDj4CfffDj5CfffDj6CfffDj7CfffDj8CfffDj9CfffDjaCfffDjbCcccDjcC555DjdCfffDjeCfffDjfC666DjgCbbbDjhCfffDjiCfffDjjCfffDjkCfffDjlCfffDjmCfffDjnC777Dk0CaaaDk1C666Dk2C222Dk3CdddDk4CfffDk5CfffDk6CfffDk7CfffDk8CfffDk9CfffDkaCfffDkbC999DkcC888DkdCfffDkeCfffDkfC999DkgC888DkhCfffDkiCfffDkjCfffDkkCfffDklCfffDkmCfffDknC777Dl0CfffDl1CdddDl2C333Dl3CdddDl4CfffDl5CfffDl6CfffDl7CfffDl8CfffDl9CfffDlaCfffDlbC888DlcCaaaDldCfffDleCfffDlfCbbbDlgC777DlhCfffDliCfffDljCfffDlkCfffDllCfffDlmCfffDlnC777Dm0CfffDm1CdddDm2C333Dm3CdddDm4CfffDm5CfffDm6CfffDm7CfffDm8CfffDm9CfffDmaCfffDmbCaaaDmcC666DmdCdddDmeCcccDmfC777DmgC888DmhCfffDmiCfffDmjCfffDmkCfffDmlCfffDmmCfffDmnC333Dn0C777Dn1C666Dn2C222Dn3CdddDn4CfffDn5CfffDn6CfffDn7CfffDn8CfffDn9CfffDnaCfffDnbCeeeDncC888DndC555DneC666DnfC888DngCeeeDnhCfffDniCfffDnjCfffDnkCfffDnlCfffDnmCfffDnn"{
	
	// Directories
	Dialog.create("Choose directories and name of the output file");
	Dialog.addDirectory("Input images", "");
	Dialog.addDirectory("Output ROIs", "");
	Dialog.addDirectory("Output results", "");
	Dialog.addString("File Name", "Traits");
	Dialog.show();
	inputDir  = Dialog.getString();
	outputDir1  = Dialog.getString();
	outputDir2  = Dialog.getString();
	filename  = Dialog.getString();
	checkInput = File.isDirectory(inputDir);
	checkOutput1 = File.isDirectory(outputDir1);
	checkOutput2 = File.isDirectory(outputDir2);
	if (checkInput == 0 || checkOutput1 == 0 || checkOutput2 == 0) {
		exit("All directories must be chosen")
	}
	
	// First image
	fileList = getFileList(inputDir);
	Dialog.create("Choose first image");
	Dialog.addChoice("From which image do you want to start?", fileList);
	Dialog.show();
	first = Dialog.getChoice();
	iFirst = iArr(fileList, first);
	
	// Number of images to analyse
	max = fileList.length - iFirst;
	Dialog.create("Number of images");
	Dialog.addSlider("How many images do you want to analyse?", 1, max, 1);
	Dialog.show();
  	total = Dialog.getNumber();
	Last = iFirst + total;

	// Create table to store the results
	name = filename + ".txt"; // add ".txt" otherwise after the first saving this is renamed
	Table.create(name);
	showMessage("", "<html>"
	     + "<b>Do not close</b> the window <i><b>" + name +"</b></i><br>"
	     + "until the end, rather minimise it.<br>"
	     + "All results will be stored here.<br>");
	
	// Loop over selected images
	newList = Array.slice(fileList , iFirst , Last);
	for (i = 0; i < newList.length; i++) {
		
		// Open image
		open(inputDir + newList[i]);
		
		// Get image ID and name
		original = getImageID();
		title = File.nameWithoutExtension;
		
		// Duplicate image, rename, and close original
		run("Duplicate...", " ");
		copy = getImageID();
		rename(title);
		selectImage(original);
		run("Close");
		
		// Open ROI manager
		run("ROI Manager...");
		roiManager("Show All with labels");
		
		// Set colors
		run("Colors...", "foreground=black background=white selection=red");
		
		// Set scale
		setScale();
		
		// Adjust the image if the fish is bended or not horizontal	
		straightenRotate();
	
		// Image size
		imageSize();
		
		// Orientation
		orientation();
		
		
		// REFERENCE LINES //

		// Line A
		makeLine(0, ymid, w, ymid);
		roiAddRename("A");
		waitForUser("Reference lines", "Reference line A: \n \nMove the line up or down to adjust its position.\n \nLine A is the middle line from the centre of the tail towards the mouth.\nIt should cross the tip of the upper jaw, or the tip of the snout.\nThis line should do the best possible job at cutting the fish in two halves.");
		getSelectionCoordinates(x, y);
		xA = x;
		yA = y;

		// Line B
		makeLine(0, ymid, w, ymid);
		roiAddRename("B");
		waitForUser("Reference lines", "Reference line B: \n \nMove the line up or down to adjust its position.\n \nLine B is parallel to A touching the lowest edge of\nthe body (excluding fins).");
		getSelectionCoordinates(x, y);
		xB = x;
		yB = y;
				
		// Line C
		makeLine(0, ymid, w, ymid);
		roiAddRename("C");
		waitForUser("Reference lines", "Reference line C: \n \nMove the line up or down to adjust its position.\n \nLine C is parallel to A touching the highest edge of\nthe body (excluding fins).");
		getSelectionCoordinates(x, y);
		xC = x;
		yC = y;
		
		// Line D
		makeLine(xmid, 0, xmid, h);
		roiAddRename("D");
		waitForUser("Reference lines", "Reference line D: \n \nMove the line to the left or right to adjust its position.\n \nLine D is perpendicular to A and should touch the anterior tip of the\npremaxilla (upper jaw). There may be few exceptions (e.g. some blennies),\nwhere D corresponds to the tip of the snout but not to the premaxilla.");
		getSelectionCoordinates(x, y);
		xD = x;
		yD = y;
		
		// Line Di
		ljaw = getBoolean("Does the lower jaw project further from line D?");
		if (ljaw == 1) {
			makeLine(xmid, 0, xmid, h);
			roiAddRename("Di");
			waitForUser("Reference lines", "Reference line Di: \n \nMove the line to the left or right to adjust its position.\n \nLine Di is parallel to D touching the anterior tip of the lower jaw.");
		} else if (ljaw == 0) {
			makeLine(xD[0], yD[0], xD[1], yD[1]);
			roiAddRename("Di");
		}
		getSelectionCoordinates(x, y);
		xDi = x;
		yDi = y;
		
		// Line E
		makeLine(xmid, 0, xmid, h);
		roiAddRename("E");
		waitForUser("Reference lines", "Reference line E: \n \nMove the line to the left or right to adjust its position.\n \nLine E is perpendicular to A at the point where the rays of the tail start \nin the middle of the tail (this line marks the end of the standard length).");
		getSelectionCoordinates(x, y);
		xE = x;
		yE = y;
		
		// Line F
		makeLine(xmid, 0, xmid, h);
		roiAddRename("F");
		waitForUser("Reference lines", "Reference line F: \n \nMove the line to the left or right to adjust its position.\n \nLine F is perpendicular to A at the narrowest point \nof the caudal peduncle.");
		getSelectionCoordinates(x, y);
		xF = x;
		yF = y;
		Froi = RoiManager.size - 1;

		// Line G
		makeLine(xmid, 0, xmid, h);
		roiAddRename("G");
		waitForUser("Reference lines", "Reference line G: \n \nMove the line to the left or right to adjust its position.\n \nLine G is perpendicular to A touching the posterior margin \nof the operculum (i.e. bone structure that covers the gills), \nor the gill opening in moray eels.");
		getSelectionCoordinates(x, y);
		xG = x;
		yG = y;
		
		// Lines H and I
		setTool("Ellipse");
		waitForUser("Reference lines", "Reference line H and I: \n \nTrace an ellipse around the eye.\nTwo perpendicular lines intersecting\nin the eye centroid will be drawn.");
		if (selectionType != 3) {
			showMessage("Elliptical selection required!");
			waitForUser("Reference lines", "Reference line H and I: \n \nTrace an ellipse around the eye.\nTwo perpendicular lines intersecting\nin the eye centroid will be drawn.");
		}
		
		setBatchMode(true);
		
		roiManager("Add");
		xEC = getValue("X")/pw;
		yEC = getValue("Y")/pw;
		makeLine(0, yEC, w, yEC);
		roiAddRename("H");
		Hroi = RoiManager.size - 1;
		eyePoints = roiIntersection(Hroi-1, Hroi);
		if (side == "left") { // Aeye is the intersection point between line H and the anterior margin of the orbit
			if (eyePoints[0] < eyePoints[2]) {
				xAeye = eyePoints[0];
				yAeye = eyePoints[1];
			} else {
				xAeye = eyePoints[2];
				yAeye = eyePoints[3];
			}
		} else if (side == "right") {
			if (eyePoints[0] < eyePoints[2]) {
				xAeye = eyePoints[2];
				yAeye = eyePoints[3];
			} else {
				xAeye = eyePoints[0];
				yAeye = eyePoints[1];
			}
		}
		roiManager("Select", Hroi-1);
		roiManager("Delete");
		makeLine(xEC, 0, xEC, h);
		roiAddRename("I");
		Iroi = RoiManager.size - 1;
		
		setBatchMode(false);


		// TRAITS //
		
		// MT1 - Body area
		setTool("Polygon");
		waitForUser("Body area", "Trace a polygon following the contour of the body excluding fins,\nand up to the narrowest point of the caudal peduncle (F).\nPay attention to cross line F by (at least) one pixel,\notherwise the narrowest point of the caudal peduncle will be NA.");
		if (selectionType != 2) {
			showMessage("Polygon selection required!");
			waitForUser("Body area", "Trace a polygon following the contour of the body excluding fins,\nand up to the narrowest point of the caudal peduncle (F).\nPay attention to cross line F by (at least) one pixel,\notherwise the narrowest point of the caudal peduncle will be NA.");
		}
		
		setBatchMode(true);
		
		run("Interpolate", "interval=1 smooth adjust");
		run("Fit Spline");
		roiManager("Add");
		
		// Intersection points along F
		nROI = RoiManager.size;
		FPoints = roiIntersection(nROI-1, Froi);
		
		// Intersection points along I
		IPoints = roiIntersection(nROI-1, Iroi);
		
		// Intersection point along H
		HPoints = roiIntersection(nROI-1, Iroi-1);
		if (side == "left") {
			if (HPoints[0] < HPoints[2]) {
				xAO = HPoints[0];
				yAO = HPoints[1];
			} else {
				xAO = HPoints[2];
				yAO = HPoints[3];
			}
		} else {
			if (HPoints[0] < HPoints[2]) {
				xAO = HPoints[2];
				yAO = HPoints[3];
			} else {
				xAO = HPoints[0];
				yAO = HPoints[1];
			}
		}
		
		// Correct MT1 by cutting the selected area at line F
		if (side == "left") {
			makeRectangle(0, 0, xF[0], h);
			roiManager("Add");
			roiManager("Select", newArray(nROI-1, nROI));
			roiManager("AND");
			roiAddRename("MT1");
			roiManager("Select", newArray(nROI-1, nROI));
			roiManager("Delete");
		} else if (side == "right") {
			makeRectangle(xF[0], 0, w, h);
			roiManager("Add");
			roiManager("Select", newArray(nROI-1, nROI));
			roiManager("AND");
			roiAddRename("MT1");
			roiManager("Select", newArray(nROI-1, nROI));
			roiManager("Delete");
		}		
		
		nROI = RoiManager.size;
		roiManager("Select", nROI-1);
		MT1 = getValue("Area");
		
		// MT2 - Standard length
		makeLine(xDi[0], yC[0], xE[0], yC[0]);
		roiAddRename("MT2");
		MT2 = getValue("Length");
		
		// MT3 - Maximum body depth
		xMBD = xG[0] + ((xF[0] - xG[0])/2);
		makeLine(xMBD, yB[0], xMBD, yC[0]);
		roiAddRename("MT3");
		MT3 = getValue("Length");
		
		// MT4 - Head length
		makeLine(xDi[0], yB[0], xG[0], yB[0]);
		roiAddRename("MT4");
		MT4 = getValue("Length");
		
		// MT5 - Head depth
		makeLine(IPoints[0], IPoints[1], IPoints[2], IPoints[3]);
		roiAddRename("MT5");
		MT5 = getValue("Length");
		
		// MT6 - Eye diameter
		makeLine(eyePoints[0], eyePoints[1], eyePoints[2], eyePoints[3]);
		roiAddRename("MT6");
		MT6 = getValue("Length");
		
		// MT7 - Anterior of orbit centroid
		makeLine(xD[0], yEC, xEC, yEC);
		roiAddRename("MT7");
		MT7 = getValue("Length");
		
		// MT8 - Posterior of orbit centroid
		makeLine(xEC, yEC, xG[0], yEC);
		roiAddRename("MT8");
		MT8 = getValue("Length");
		
		// MT9 - Anterior of orbit
		makeLine(xAeye, yAeye, xAO, yAeye);
		roiAddRename("MT9");
		MT9 = getValue("Length");
		
		// MT10 - Snout length
		makeLine(xD[0], yC[0], xAeye, yC[0]);
		roiAddRename("MT10");
		MT10 = getValue("Length");
		
		// MT11 - Eye position
		makeLine(xEC, yB[0], xEC, yEC);
		roiAddRename("MT11");
		MT11 = getValue("Length");
		
		setBatchMode(false);
		
		// MT12 - Oral gape position
		run("Point Tool...", "type=Dot color=Red size=[Extra Large]");
		setTool("Point");
		waitForUser("Oral gape position", "Click on the tip of the premaxilla (upper jaw). \nAfter the point appears, you can click and \ndrag it if you need to readjust.");
		if (selectionType != 10) {
			showMessage("Point selection required!");
			waitForUser("Oral gape position", "Click on the tip of the premaxilla (upper jaw). \nAfter the point appears, you can click and \ndrag it if you need to readjust.");
		}
		getSelectionCoordinates(x, y);
		xOGP = x;
		yOGP = y;
		makeLine(xOGP[0], yOGP[0], xOGP[0], yB[0]);
		roiAddRename("MT12");
		MT12 = getValue("Length");
		
		// MT13 - Maxillary jaw length
		waitForUser("Maxillary jaw length", "Click on the intersection between the maxilla \nand the mandible (i.e. the corner of the mouth). \nAfter the point appears, you can click and \ndrag it if you need to readjust.");
		if (selectionType != 10) {
			showMessage("Point selection required!");
			waitForUser("Maxillary jaw length", "Click on the intersection between the maxilla \nand the mandible (i.e. the corner of the mouth). \nAfter the point appears, you can click and \ndrag it if you need to readjust.");
		}
		getSelectionCoordinates(x, y);
		xJL = x;
		yJL = y;
		makeLine(xJL[0], yJL[0], xOGP[0], yOGP[0]);
		roiAddRename("MT13");
		MT13 = getValue("Length");
		
		// MT14 - Orbit centroid to mouth
		makeLine(xEC, yEC, xOGP[0], yOGP[0]);
		roiAddRename("MT14");
		MT14 = getValue("Length");

		// MT15 - Eye-mouth angle
		makeSelection("angle", newArray(xEC, xOGP[0], xEC), newArray(yEC, yOGP[0], yOGP[0]));
		roiAddRename("MT15");
		MT15 = getValue("Angle");
		
		// MT16 - Narrowest depth of caudal peduncle
		makeLine(FPoints[0], FPoints[1], FPoints[2], FPoints[3]);
		roiAddRename("MT16");
		MT16 = getValue("Length");
		
		
		// Save overlay
		//roiManager("Deselect");
		//run("From ROI Manager");
		//run("Labels...", "color=white font=12 show use draw bold");
		//saveAs("tiff", outputDir1 + title);
		//close("Roi Manager");
		
		// Save ROIs
		roiManager("Deselect");
		roiManager("Save", outputDir1 + title + "_RoiSet.zip");
		selectWindow("ROI Manager");
		run("Close");
		
		// Save image if rotated or straightened
		if (straighten == 1) {
			 saveAs("Jpeg", outputDir1 + title + "_straightened");
		} 
		else if (straighten == 0 && rotate == 1) {
			saveAs("Jpeg", outputDir1 + title + "_rotated");
		}
		
		// Add results to the table
		selectWindow(name);
		Table.set("px/cm", i, 1/pw);
		Table.set("ID", i, title);
		Table.set("MT1", i, MT1);
		Table.set("MT2", i, MT2);
		Table.set("MT3", i, MT3);
		Table.set("MT4", i, MT4);
		Table.set("MT5", i, MT5);
		Table.set("MT6", i, MT6);
		Table.set("MT7", i, MT7);
		Table.set("MT8", i, MT8);
		Table.set("MT9", i, MT9);
		Table.set("MT10", i, MT10);
		Table.set("MT11", i, MT11);
		Table.set("MT12", i, MT12);
		Table.set("MT13", i, MT13);
		Table.set("MT14", i, MT14);
		Table.set("MT15", i, MT15);
		Table.set("MT16", i, MT16);
		Table.update;
		
		// Save results
		saveAs("results", outputDir2 + name);
		
		// Close image
		close();
	}
showMessage("Analysis completed", "<html>"
     +"You have measured traits for <b>"+total+"</b> images.<br><br>"
     + "The ROIs have been save here:<br>"
     + outputDir1 +"<br><br>"
     + "The results have been saved here:<br>"
     + outputDir2
     + "<br><br>Please check they are saved correctly<br>"
     + "before closing the table <i><b>" + name +"</b></i>");
exit;
}

///////////////////////////////////////////  END  /////////////////////////////////////////////////
