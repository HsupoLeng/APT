#### APT
Animal Part Tracker

#### Requirements
MATLAB R2014b or later. Development is being done on Win7/R2015a with some testing on Linux.

#### Usage
```
% in MATLAB
cd /path/to/git/APT/checkout
APT.setpath % configures MATLAB path 
edit pref.yaml % set labeling config/prefs (see below)
lObj = Labeler;
```

Go to the File> menu to open a movie or movie+trx. 

#### Description

###### Configuration/Preferences: pref.yaml
Edit /\<APTRoot\>/pref.yaml to set up your labeler. Most importantly:

* **LabelMode** specifies your labeling mode; see LabelMode.m for options. The labeling mode is also automatically set when loading an existing project.
* **NumLabelPoints**.
* **LabelPointsPlot**. Items under this parent specify cosmetics for clicked/labeled points. For HighThroughputMode, **NFrameSkip** specifies the frame-skip. 

###### Sequential Mode
Click the image to label. When NumLabelPoints points are clicked, adjust the points with click-drag. Hit accept to save/lock your labels. You can hit Clear at any time, which starts you over for the current frame/target. Switch targets or frames and do more labeling; the Targets and Frames tables are clickable for navigation. See the Help> menu for hotkeys. When browsing labeled (accepted) frames/targets, you can go back into adjustment mode by click-dragging a point. You will need to re-accept to save your changes. When you are all done, File>Save will save your results.

###### Template Mode
The image will have NumLabelPoints white points overlaid; these are the template points. Click-drag to adjust, or select points with number keys and adjust with arrows or mouse-clicks. Points that have been adjusted are colored. See the Help> menu for hotkeys. Click Accept to save/lock your labels. Switch targets/frames and the template will follow. 

###### HighThroughput (HT) Mode
In HT mode, you label the entire movie for point 1, then you label the entire movie for point 2, etc. Click the image to label a point. After clicking/labeling, the movie is automatically advanced NFrameSkip frames. When the end of the movie is reached, the labeling point is incremented, until all labeling for all NumLabelPoints is complete. You may manually change the current labeling point in the Setup>HighThroughput Mode menu.

HT mode was initially intended to work on movies with no existing trx file (although this appears to work fine). See "Track/Retrack" below for further usage.

###### Projects
For labeling single movies (with or without trx), use the File>Quick Open Movie menu option. This prompts you to find a moviefile and (optional) trxfile.

When you open a movie in this way, you are actually creating a new Project with a single movie. When you are done labeling or reach a waypoint, you may save your work via the File>Save Project or File>Save Project As.

Conceptually, a Project is just a list of movies (optionally with trx files), their labels, and labeling-related metadata (such as the labeling mode in use). The File>Manage Movies menu lets you add/remove movies to your project, switch the current movie being labeled, etc. By default Projects are saved to files with the .lbl extension.

###### Occluded
To label a point as occluded, click in the box in the lower-left of the main image. Depending on the mode, you may be able to "unocclude" a point, or you can always push Clear.

Occluded points appear as inf in the .labeledpos arrays.

###### Suspiciousness
The Labeler currently allows an externally-computed scalar statistic to be associated with each movie/frame/target. For example one may compute a "suspiciousness" parameter based on the tracking of targets in a movie. The suspiciousness can then be used for navigation within the Labeler (and in the future, notes/curation etc).

Currently, suspiciousness statistics are externally computed and set on the Labeler using **setSuspScore**:
    
``` 
...
lObj = Labeler;
% Open a movie, do some labeling etc
ss = rand(lObj.nframes,lObj.nTargets); % generate random suspiciousness score (demo only)
ss(~lObj.frm2trx) = nan; % set suspScore to NaN where trx do not exist
lObj.setSuspScore({ss}); % set/apply suspScore (cell array because we are setting score for 1st/only movie) 
```

Once a suspScore is set, navigation via the Suspiciousness table is enabled. This table can be sorted by column, but for large movies the performance can be painful.

Note, the Labeler property **.labeledpos** contains all labels for the current project, if these are needed for computing the Suspiciousness. 

###### (Re)Tracking trajectories
(Re)Tracking functionality is currently designed for an iterative workflow where labels are used to update/refine trajectories generated by an external tracker and those new trajectories are used to refine/add labels etc.

To use this functionality, you must first create a Tracker object, which is any handle object with a track() method. For an example, see ToyTracker.m; your track() method must accept the same signature. The track() method accepts the current trajectories and labels, and computes new trajectories.

Tracking is still preliminary, with the current prototype design supporting the following workflow. Consider one of AH's MouseReach movies, which does not have associated trajectories, and suppose we want to track each paw (say in the side view), creating a .trx file with two trajectories, with help from the Labeler.

1. Given an AH MouseReach movie movie_comb.001, create an initial trajectory file paws.trx (save it anywhere) containing two trx elements with start/endframes set appropriately for movie_comb.001. TrxUtil/createSimpleTrx and TrxUtil/initStationary could be useful for this.
2. Configure the Labeler for Sequential-mode labeling, with 2 label points.
3. Start the Labeler, and open movie_comb.001 with paws.trx.
4. Create/set the ToyTracker object with 'trker = ToyTracker; lObj.setTracker(trker);'.
5. This is a little quirky: when Labeling, ignore the fact that there are two trajectories/targets. Instead, leave the first target selected. Use point 1 for the first paw and point 2 for the second paw. 
6. Label a few points. At a minimum, make sure to label the first and last frame of the movie (the ToyTracker clips the trx to start/end at the first/last labeled frames).
7. The Track>Retrack menu item will call the ToyTracker with your labels. The ToyTracker just does a linear interpolation between all labels. The new/resulting trx is then set on the Labeler.
8. Repeat steps 5-7.
9. To save your trx, use Track>Save Trx.


