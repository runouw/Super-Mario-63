// This is an attempt to remove the .png and .gif files from their .bin files
// https://stackoverflow.com/questions/4082812/xfl-what-are-the-bin-dat-files

/**
 * Converts a filename in a platform-specific format to a file:/// URI.
 * @param	path	A string, expressed in a platform-specific format, specifying the filename you want to convert.
 * @return			A string expressed as a file:/// URI.
**/
function platformPathToURI(path) {
	if (isCS4()) {
		return FLfile.platformPathToURI(path);
	} else {
		if (isMac()) {
			path = path.replace(/ /g, "%20");
			path = "file:///" + path;
		} else {
			path = path.replace(/:\\/, "|/");
			path = path.replace(/\\/, "/");
			path = escape(path);
			path = "file:///" + path;
		}
		return path;
	}
}

/**
 * Converts a filename expressed as a file:/// URI to a platform-specific format.
 * @param	uri		A string, expressed as a file:/// URI, specifying the filename you want to convert.
 * @return			A string representing a platform-specific path.
**/
function uriToPlatformPath(uri) {
	if (isCS4()) {
		return FLfile.uriToPlatformPath(uri);
	} else {
		if (isMac()) {
			uri = uri.replace("file:///", "");
			uri = uri.replace("%20", " ");
		} else {
			uri = unescape(uri);
			uri = uri.replace(/file:\/\/\/([A-Z])|/, "$1:");
			uri = uri.replace("file:///", "");
			uri = uri.replace(/\//g, "\\");
		}
		return uri;
	}
}


/**
 * Determines if the script is running on a Mac or not.
 * @return	A Boolean value of true if running on a Mac; false otherwise.
**/
function isMac() {
	return (fl.version.search(/mac/i) > -1);
}

/**
 * Determines if the script is running in Flash CS4 or higher, or not.
 * @return	A Boolean value of true if running CS4 or higher; false if running CS3 or lower.
**/
function isCS4() {
	var versionRE = /(\w+)\s+(\d+)(,\d+)+/;
	var matches = versionRE.exec(fl.version);
	var majorVersion = parseInt(matches[2]);
	if (majorVersion >= 10) {
		return true;
	}
	return false;
}

String.prototype.endsWith = function(suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
};

if (!String.prototype.trim) {
    (function() {
        // Make sure we trim BOM and NBSP
        var rtrim = /^[\s\uFEFF\xA0]+|[\s\uFEFF\xA0]+$/g;
        String.prototype.trim = function() {
            return this.replace(rtrim, '');
        };
    })();
}

function generatePath(libPath) {
    fl.outputPanel.trace("working on ->" + libPath);

    // fix libPath

    var splitPath = libPath.split('/');
    for (var i = 0; i < splitPath.length; i++) {
        // handle illigal characters in path
        splitPath[i] = splitPath[i].replace(":", "&#058");
        splitPath[i] = splitPath[i].replace(",", "&#044");

        // flashplayer also trims the paths
        splitPath[i] = splitPath[i].trim();
    }

    libPath = splitPath.join("/");
    
    // export as png
    
    var resultPath = folderURI + "/" + libPath + ".png";
    
    return resultPath;
}

//created by Heitara

// var folderURI = fl.browseForFolderURL('Select path to LIBRARY folder');
// folderURI = platformPathToURI(folderURI);

var folderURI = "file:///C|/Users/Robert/Documents/dev/active/SM63_Open_Source/Super_Mario_63_2010/LIBRARY"

var doc = fl.getDocumentDOM();
var newDoc = fl.createDocument();

if(doc && newDoc)
{
    fl.outputPanel.trace("Start");
    var library = doc.library;
    var allLibItems = library.items;
    var item;
    var c = 0;
    var selectedItemOnStage;
    var selectionArray;

    for (var i = 0; i < allLibItems.length; i++) {
        item = allLibItems[i];//only images will be processed
        if (item.itemType == "bitmap") {
            var resultPath = generatePath(item.name);

            // wish this would work: (read only)
            item.sourceFilePath = resultPath;
			
			fl.outputPanel.trace("Saving file: " + resultPath);

            // attach image
            newDoc.addItem({x:0.0, y:0.0}, item);

            //postition all items on (0,0) 
            var image = newDoc.getTimeline().layers[0].frames[0].elements[0];
            if (image) {

                var hpx = image.hPixels;
                var vpx = image.vPixels;

                newDoc.width = hpx;
                newDoc.height = vpx;
                // we need to reposition the image, otherwise it will be centered
                image.x = 0;

                image.y = 0;
            }

            fl.outputPanel.trace(doc.pathURI);
			
            var result = newDoc.exportPNG(resultPath, true, true);

            if (result == false) {
                fl.outputPanel.trace("ERROR in document.exportPNG");
                break;
            }
            
            // reset document

            newDoc.selectAll();
            if (newDoc.selection.length > 0) {
                newDoc.deleteSelection();
                newDoc.selectNone();
            }
        }

    }
}

//close the new document withut saving it
fl.closeDocument(newDoc, false);