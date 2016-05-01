function varargout=resampleVolume(channel,targetDims,fileFormat)
% Get a directory with stitched images as input and resample them to a different resolution
%
% function [volume,fname]=resampleVolume(channel,targetDims,fileFormat)
%
% PURPOSE
% The idea is to use this function to down-sample data for warping data to a standard brain.
% Therefore the dataset size produced by this function should fit comfortably in RAM. It 
% will likely choke and die if you ask for a dataset size which cannot do this. Some error-
% checking is provided to avoid this. This function requires the stitchedImages_100 directory
% to be present. 
%
%
% INPUTS
% channel - which channel to resize (e.g. stitchedImages_100)
% targetDims - vector of length 2 defining the pixel resolution in [xy,z] of data in resample
%              if the user enters a scalar (e.g. 25) then this is expanded to a vector of length 2
% fileFormat - [optional] by default is 'mhd'. Can also be 'tiff' This determines which
%            output format is used for the saved stack.
%
%
% OUTPUTS [optional]
% volume - The image volume is [CAUTION: may be large]
% fname -  The downsampled file name minus the extension.
% 
%
% EXAMPLES
% This will produce a down-sampled stack that's the same size as the second-gen ARA:
% cd /path/to/experiment/root/dir
% resampleVolume(2,[20,50])
%
% This will produce and 25 micron voxel (3rd gen ARA-sized)
% resampleVolume(2,[25,25])
% resampleVolume(2,25)
%
%
% NOTES
% The Osten Lab ARA from the 2015 paper is 20 x 20 x 50 microns
% The Allen Atlas v3 comes in a variety of sizes, all with cubic voxels. The most useful size is probably 25 micron
%
%
% Rob Campbell - Basel 2014




origDataDir = sprintf('stitchedImages_100%s%d%s',filesep,channel,filesep);
files=dir([origDataDir,'sec*.tif']);
if isempty(files)
  error('No tiffs found in %s',origDataDir)
end

if ~isnumeric(targetDims)
  error('input argument targetDims should be numeric')
end

if length(targetDims)==1
  targetDims = repmat(targetDims,1,2);
end

if length(targetDims) ~= 2
  error('targetDims should have a length of 2')
end

if nargin<3
  fileFormat = 'mhd';
end

fileFormat = lower(fileFormat);
if strcmp(fileFormat,'tif')
  fileFormat = 'tiff';
end

if isempty(strmatch(fileFormat,{'tiff','mhd'}))
  error('fileFormat should be the string "tiff" or "mhd')
end


if length(targetDims) ~= 2
  error('targetDims should have a length of 2')
end

%Calculate the original image size
params=readStitchItINI;
xy=params.micsPerPixel.micsPerPixelMeasured;
M=readMetaData2Stitchit;
z=M.voxelsize.z;
origDims = [xy,z];
fprintf('original resolution %d um in x/y and %d um in z\n', round(xy), z)


info=imfinfo([origDataDir,files(1).name]);
imSizeInMegs = (info.Width*info.Height*2)/1024^2;


%get the ratio for the size difference between the original and target volumes
origVol   = origDims(1)^2 * origDims(2);
targetVol = targetDims(1)^2 * targetDims(2); %should be bigger because we're down-sampling

if origVol >targetVol
  error('up-sampling not permitted')
end

downSampleRatio = targetVol/origVol;

finalDataSizeInMB = (imSizeInMegs*length(files))/downSampleRatio;


%If the target data size is very, very, large, then we issue an error. 
%If it's just big we issue a warning and proceed anyway
errorSize=2^13;
warningSize=2^10;
if finalDataSizeInMB>errorSize
  error('Target data size is over % MBd\n',errorSize)
elseif finalDataSizeInMB>warningSize
  fprintf('WARNING: Target data size is over %d MB\n',warningSize)
end


%Create file name
paramFile=getTiledAcquisitionParamFile;
%TODO: the following will fail with BakingTray Data
downsampledFname=sprintf([regexprep(paramFile(1:end-4),'Mosaic_','ds'),'_%d_%d_%02d'],targetDims,channel);
fid = fopen([downsampledFname,'.txt'],'w');

metaData = readMetaData2Stitchit(paramFile);
fprintf(fid,'Downsampling %s\nAcquired on: %s\nDownsampled: %s\n', metaData.sample.ID, metaData.sample.acqStartTime, datestr(now));
if strcmp('tiff',fileFormat)
  downsampledFname=[downsampledFname,'.tif'];
end
fprintf(fid,'downsample file name: %s\n',downsampledFname);

%report what we will do
xyRescaleFactor = origDims(1)/targetDims(1);
zRescaleFactor = targetDims(2)/origDims(2);
msg = sprintf('Begining to downsample:\nx/y: %0.3f\nz: %0.3f\n',1/xyRescaleFactor,zRescaleFactor);
fprintf(msg);
fprintf(fid,'\n---log---\n%s',msg);


%Rescale in x/y and store resampled volume in RAM
xyRescaleFactor = origDims(1)/targetDims(1);
msg=sprintf('Loading and down-sampling x/y by %0.3f\n',1/xyRescaleFactor);
fprintf(msg)
fprintf(fid,msg);

vol=openTiff([origDataDir,filesep,files(1).name]);
vol=imresize(vol,xyRescaleFactor);
vol(:,:,2:end)=nan;
vol=repmat(vol,[1,1,length(files)]);

parfor ii=1:length(files)
  fprintf('Resampling %03d\n', ii)
  im=openTiff([origDataDir,files(ii).name]);
  vol(:,:,ii)=imresize(im,xyRescaleFactor);
end


if nargout>0
  varargout{1}=vol;
end


%resample in z
if zRescaleFactor ~= 1
  msg=sprintf('Rescaling in z by %0.4f\n',zRescaleFactor);
  fprintf(msg)
  fprintf(fid,msg);

  dims=size(vol);

  %numZplanes;
  newZ=round(dims(3)/zRescaleFactor);
  downSampledZ=ones([dims(1:2),newZ],class(vol));

  parfor ii=1:dims(1)
    thisSlice = squeeze(vol(ii,:,:));
    thisSlice=imresize(thisSlice,[dims(2),newZ]);
    downSampledZ(ii,:,:)=thisSlice;
  end

  vol=downSampledZ;

else
  fprintf('Z sampling is already correct\n')
end

%Save the data
vol=uint16(vol);  
try
  fprintf('Saving to %s\n',downsampledFname)
  if strcmp('tiff',fileFormat)
    save3Dtiff(vol,downsampledFname)
  elseif strcmp('mhd',fileFormat)
    mhd_write(vol,downsampledFname,[1,1,1])
  else
    %This should *never* execute as we've already checked the file format string 
    %at the start of the function. Nonetheless, we leave this code "just in case"
    msg = fprintf('NOT SAVING IMAGE STACK: file format %s unknown\n',fileFormat)
    fprintf(msg)
    fprintf(fid,msg);
  end

catch
  msg=sprintf('failed to save\n');
  fprintf(msg)
  fprintf(fid,msg);

end

if nargout>0
  varargout{1}=vol;
end

if nargin>1
  varargout{2}=downsampledFname;
end

msg = sprintf('Done\n');
fprintf(msg);
fprintf(fid,msg);
fclose(fid);