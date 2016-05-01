function [out,sucessfulRead,rawOut]=readMetaData2Stitchit(obj,fname,verbose)
% For user documentation run "help readMetaData2Stitchit" at the command line


%Input argument error checking 
if nargin<2
	fname=obj.getTiledAcquisitionParamFile;
end
if ~exist(fname,'file')
	error('Can not find parameter file: %s',fname)
end

if nargin<3
	verbose=0;
end

%Read the TissueCyte mosaic file
[rawOut,sucessfulRead]=obj.readMosaicMetaData(fname,verbose);

if ~sucessfulRead
	error('Failed to read %s',fname)
end

out = mosaic2StitchIt(rawOut,fname);

%TODO:
% Save the stitchit file to the current directory. But don't do it yet, because we need
% to be sure that the format of the file is as we want it to be. 




%------------------------------------------------------------------------
function out = mosaic2StitchIt(raw,fname)
%Convert the TissueCyte structure to a StitchIt structure

out.paramFileName=fname; %The name of the Mosaic file


%  Sample
out.sample.ID = raw.SampleID;
out.sample.acqStartTime = raw.acqDate; %convert from: '10/9/2015 10:10:49 AM'
out.sample.objectiveName='';
out.sample.scanmode='tile';
out.sample.excitationWavelength = raw.excwavelength; %depends on the user filling this in
out.modulatorSetPoint=[]; %empty, but could be a vector of, say, Pockels cell values

if raw.channels==3
	out.sample.activeChannels=1:3;
elseif raw.channels==1
	out.sample.activeChannels=1;
end


%Scene
out.scene=[];


%Mosaic
out.mosaic.sectionStartNum=raw.startnum; %The index of the first section
out.mosaic.numSections=raw.sections; %How many physical sections did the user ask for?
out.mosaic.sliceThickness=raw.sectionres; 
out.mosaic.numOpticalPlanes=raw.layers; %Number of optical sections per physical section
out.mosaic.overlapProportion=[];


% tile
% The number of columns and rows of voxels in each tile
out.tile.nRows=raw.rows;
out.tile.nColumns=raw.columns;


%  Voxel size
out.voxelsize.x=raw.xres; %x means along the direction of the x stage
out.voxelsize.y=raw.yres; %y means along the direction of the y stage
out.voxelsize.z=raw.zres*2;


% NUMTILES 
%The number of tiles the system will take in x and y
out.numTiles.X=raw.mrows; %x means along the direction of the x stage
out.numTiles.Y=raw.mcolumns; %y means along the direction of the y stage


% TILESTEPSIZE
%The size of each tile step size
out.TileStepSize.X=raw.mrowres; %x means along the direction of the x stage
out.TileStepSize.Y=raw.mcolumnres; %y means along the direction of the y stage


% SYSTEM
out.System.ID=raw.ScannerID;
out.System.type='TissueCyte';
out.System.excitationLaserName='';


% SLICER
out.Slicer.frequency=raw.VibratomeFrequency;
out.Slicer.bladeApproachSPeed=raw.VibratomeStageSpeed;
out.Slicer.postCuttingWaitTime=raw.VibratomeDelay;
out.Slicer.cuttingSpeed=raw.SliceTranslationSpeed;


%Fill in the system specific fields
TVfields={'comments','Description','Pixrestime',...
		'PdTauFwd','PdTauRev','MCSkew','ScanRange','ScannerVScalar',...
		'TriggerLevel','ImageAdjFactor','ZdefaultVoltage','ZScanDirection',...
		'Zposition','ZWaitTime','Zscan'};

for ii=1:length(TVfields)
	out.systemSpecific.(TVfields{ii}) = raw.(TVfields{ii});
end

%X and Y stage positions
% The TissueCyte saves the stage positions in the section-specific mosaic files

if ~isempty(raw.XPos)
	out.stageLocations.requestedStep.X = raw.XPos(:,1); %What was the motion step requested by the microscope?
	out.stageLocations.expected.X = cumsum(raw.XPos(:,1)); %Infer what the position shoudld be
	out.stageLocations.reported.X = raw.XPos(:,2);

end

if ~isempty(raw.YPos)
	out.stageLocations.requestedStep.Y = raw.YPos(:,1); %What was the motion step requested by the microscope?
	out.stageLocations.expected.Y = cumsum(raw.YPos(:,1)); %Infer what the position shoudld be
	out.stageLocations.reported.Y = raw.YPos(:,2);
end