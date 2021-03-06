function  [J taskTime jobOverhead] = sacCheckJobStatus(J,Z,d,searchMode,tRemain,refillFlag,taskTime,jobOverhead)
%
%   [J taskTime jobOverhead] = sacCheckJobStatus(J,Z,d,searchMode,tRemain,refillFlag,taskTime,jobOverhead)
%   J = sacCheckJobStatus(J,Z,d,searchMode,tRemain,refillFlag);
%
% refillFlag = 1 (add new jobs, if possible). = 0 do not add new jobs.


global logFID;

if ~exist('refillFlag', 'var')
    refillFlag = 1;
end

if ~exist('taskTime', 'var')
    taskTime = 0;
end


unfinishedJobs = find([J.running] == 1);
numRunningJobs = sum([J(:).running]);


for j = unfinishedJobs
    
    % get the state of job j -  distributed computing toolbox sometimes 
    % fails to get job state. added try-catch for robustness
    stateRetrieved = 0;
    try
        state = J(j).job.State;
        stateRetrieved = 1;
    catch err
        sacLog(2,logFID,'Failed to get job state! %s\n', err.identifier);
    end
    
    if stateRetrieved
        switch state
            case 'finished'
                
                if J(j).cancelled == 1
                    continue;
                end
                
                % check to see if the job failed
                if ~isempty(J(j).job.Tasks.ErrorIdentifier)
                    if ~strcmpi(J(j).job.Tasks.ErrorIdentifier,'distcomp:task:Cancelled')
                        sacLog(2,logFID, ' Warning: an Error was encountered in Job %d\n',  J(j).job.ID );
                        fid = fopen([J(j).logfile], 'a');
                        sacLog(1,fid,' Error: %s\n', J(j).job.Tasks.ErrorMessage);
                        for i = 1:length(J(j).job.Tasks.Error.stack) 
                            sacLog(1, fid, '    %s at %d\n', J(j).job.Tasks.Error.stack(i).name, J(j).job.Tasks.Error.stack(i).line); 
                        end
                        %error(['Error in a task from Job ' num2str(J(j).job.ID) '! ']);
                    end
                end
                
                J(j).running = 0;
                J(j).finished = 1;
                J(j).duration = getRunTime(J(j).job);
                
                tTime = J(j).duration/ J(j).numTasks;
                
                completedJobs = sum([J(:).finished]);
                if completedJobs == 1
                    % this is the frist completed job
                    out = getAllOutputArguments(J(j).job);
                    if ~isempty(out)
                        t = out{2};
                        jobOverhead = J(j).duration - sum(t);
                        taskTime = tTime - jobOverhead;
                    else
                        error('the first job did not provide valid output');
                    end
                else
                    % all subsequent completed jobs
                    comp = max(1,completedJobs - Z.clusterSize);  % used to do weighted averaging
                    taskTime = (comp/(comp+1))*taskTime + (1/(comp+1)) * tTime;
                end
                sacLog(4,logFID,'   Job %d finished (%d/%d) in %0.5gs\n', J(j).job.ID, completedJobs, numel([J(:).finished]), J(j).duration);
                sacLog(4,logFID,'       --> Updated taskTime = %0.5gs\n', taskTime);

            case 'running'
                runningTime = getRunTime(J(j).job);
                if runningTime > J(j).timeLim
                    sacLog(4,logFID,'     !cancelling job %d, timeout exceeded\n', J(j).job.ID);
                    fid = fopen([J(j).logfile], 'a');
                    sacLog(4,fid,'    cancelled job %d, runningTime (%0.5gs) > timeLim (%0.5gs)\n', J(j).job.ID, runningTime, J(j).timeLim);
                    cancelJob( J(j).job );
                    J(j).running = 0;
                    J(j).finished = 0;
                    J(j).cancelled = 1;
                end
        end
    end
end

if refillFlag
    % if there are empty slots, add a job to fill one!
    if numRunningJobs < Z.clusterSize
        numNewJobs = Z.clusterSize - numRunningJobs;
        for i = 1:numNewJobs
            %newJob = sacDynamicJobGenerator(d, taskTime, tRemain, Z, metrics);
            newJob = sacCreateDistributedJob(d,Z,searchMode,'auto',tRemain,taskTime,jobOverhead);
            if ~isempty(newJob)
                J(end+1) = newJob; %#ok<AGROW>
            end
        end
    end
end










function runTime = getRunTime(job)

% sometimes the job startime is not available
tStart = [];
while isempty(tStart)
    tStart = job.StartTime;
    pause(0.05);
end
if isempty(tStart)
    job
    keyboard;
end
tStart = strrep(tStart, 'CEST', '');
tStart = regexprep(tStart, '[ \t\r\f\v]+', ' ');
tStart = tStart(5:end);
dv = datenum(tStart, 'mmm dd HH:MM:SS yyyy');

tRun = now - dv;
tRun = datevec(tRun);

runTime = tRun(6) + 60*tRun(5) + 60*60*tRun(4) + 24*60*60*tRun(3);




function cancelJob(job)

cancel(job);
pause(0.1);  % added a pause to avoid spamming the job manager






