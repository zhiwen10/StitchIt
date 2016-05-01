function data=readTileIndex(fname)
% Read tile index index data from binary file
%
% function data=readTileIndex(fname)
%
% Purpose
% StitchIt creates an index file (see generateTileIndex) that associates each tile with a 
% position in the full volume. readTileIndex reads this file (which is a binary file).
%
%
% Inputs
% fname - the relative or absolute path to the binary file containing the tile index data
%
%
% Outputs
% data - matrix containing the imported data. The numbers on each row are:
% 1. file index
% 2. z-section index
% 3. optical section
% 4. tile row
% 5. tile column
% 6. presence of chan 1 [0/1]
% 7. presence of chan 2 [0/1]
% 8. presence of chan 3 [0/1]
%
%
% Rob Campbell - Basel 2014 



fid=fopen(fname,'r');

data=fread(fid,'uint32');

intsInRow=data(1);

data(1)=[];

data=reshape(data,intsInRow,length(data)/intsInRow)';

fclose(fid);