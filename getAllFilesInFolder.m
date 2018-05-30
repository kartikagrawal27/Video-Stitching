function fname = getAllFilesInFolder(folderName)

finfo = dir(folderName);
j=1;

if length(finfo)>2

    for i=1:length(finfo)
        fnameCurr = finfo(i).name;
        if fnameCurr(1)~='.'
            % Extract the filename
            fname{j} = fnameCurr;
            j=j+1;
        end
    end

end