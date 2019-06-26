function sortToFolders(inputDir,targetDir,csvFile)
%sortToFolders(inputDir,targetDir,csvFile)
%   script to sort the generated files to groups

    if nargin<1
        inputDir = '/home/biomag/szkabel/generated';
    end
    if nargin<2
        targetDir = '/home/biomag/szkabel';
    end
    if nargin<3
        csvFile = '/home/biomag/szkabel/styles.csv';
    end

    d = dir(fullfile(inputDir));
    T = readtable(csvFile,'Delimiter',',');

    % create thrash dir
    tdir=fullfile(targetDir,'thrash');
    mkdir(tdir);

    parfor i=1:numel(d)        
        for j=1:length(T.Style)
            [~,exExtFileName,~] = fileparts(d(i).name);
            [~,exExtTableName,~] = fileparts(T.Name{j});
            
            if strcmp(exExtFileName,exExtTableName)
                target = T.Style(j);
                if target ~= -1
                    tcd = fullfile(targetDir,['group_' num2str(target,'%03d')]);
                    if ~isdir(tcd), mkdir(tcd); end            
                    copyfile(fullfile(inputDir,d(i).name),fullfile(tcd,d(i).name));
                    break;
                else
                    tcd = fullfile(targetDir,'thrash');
                    %if ~isdir(tcd), mkdir(tcd); end            
                    copyfile(fullfile(inputDir,d(i).name),fullfile(tcd,d(i).name));
                    break;
                end
            end
        end
    end
end
