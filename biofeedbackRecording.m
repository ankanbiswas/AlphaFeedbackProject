% This is the main program to run a recording session.

function biofeedbackRecording(subjectName)

%%%% Set up the control panel to start, stop, calibrate, run and exit %%%%%
hControlPanel = uipanel('Title','Controls','fontSize', 12, ...
    'Unit','Normalized','Position',[0 0.9 0.25 0.1]);

% Create pushbuttons
hStartStop = uicontrol('Parent',hControlPanel,'style','togglebutton','string','Start',...
    'Unit','Normalized','Position',[0 0.5 0.5 0.5],'Callback',{@Callback_StartStop});

uicontrol('Parent',hControlPanel,'style','pushbutton','string','Exit',...
    'Unit','Normalized','Position',[0.5 0.5 0.5 0.5],'Callback',{@Callback_Exit});

uicontrol('Parent',hControlPanel,'style','pushbutton','string','Calibrate',...
    'Unit','Normalized','Position',[0 0 0.5 0.5],'Callback',{@Callback_Calibrate});

uicontrol('Parent',hControlPanel,'style','pushbutton','string','Run',...
    'Unit','Normalized','Position',[0.5 0 0.5 0.5],'Callback',{@Callback_Run});

%%%%%%%%%%%%%%%%%%%%%%%% Set up the progress panel %%%%%%%%%%%%%%%%%%%%%%%%
[trialTypeList,folderName,sessionNum,trialNum] = createExperiment(subjectName);

hProgressPanel = uipanel('Title','Progress','fontSize',12, ...
    'Unit','Normalized','Position',[0.25 0.9 0.25 0.1]);

uicontrol('Parent',hProgressPanel,'Style','text','Unit','Normalized',...
    'String','Session No','Position',[0 0.5 0.5 0.5]);

hSessionNum = uicontrol('Parent',hProgressPanel,'style','edit','String',num2str(sessionNum),...
    'Unit','Normalized','Position',[0.5 0.5 0.5 0.5]);

uicontrol('Parent',hProgressPanel,'Style','text','Unit','Normalized',...
    'String','Trial No','Position',[0 0 0.5 0.5]);

hTrialNum = uicontrol('Parent',hProgressPanel,'style','edit','string',num2str(trialNum),...
    'Unit','Normalized','Position',[0.5 0 0.5 0.5]);

%%%%%%%%%%%%%%%%%%%%%%%% Set up the Ranges panel %%%%%%%%%%%%%%%%%%%%%%%%%%
hRangesPanel = uipanel('Title','Ranges','fontSize',12, ...
    'Unit','Normalized','Position',[0.5 0.9 0.25 0.1]);

uicontrol('Parent',hRangesPanel,'Style','text','Unit','Normalized',...
    'String','Alpha Range (Hz)','Position',[0 0.5 0.5 0.5]);

hAlphaMin = uicontrol('Parent',hRangesPanel,'style','edit','String','8',...
    'Unit','Normalized','Position', [0.5 0.5 0.25 0.5]);

hAlphaMax = uicontrol('Parent',hRangesPanel,'style','edit','String','13',...
    'Unit','Normalized','Position', [0.75 0.5 0.25 0.5]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Generate Plots %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hRawTrace               = subplot('Position',[0.05 0.7 0.7 0.14],'XTickLabel',[]);
hTF                     = subplot('Position',[0.05 0.55 0.7 0.14]);
%hPSD                    = getPlotHandles(1,2,[0.7517,0.5375,0.235,0.1938],0.05,0.05,0);

%%%%%%%%%%% Initializing the parameters for the main programme %%%%%%%%%%%%

state = 0; % by default state is zero which would be updated according to the case

% Set up communication with EEG device and run in synthetic mode if connection
% is not made.
if ispc
    [cfg,sock] = rda_open;
    if sock == -1
        hdr = getSynthDataHeader;
    else
        hdr = rda_header(cfg,sock); % rda_open would pass the socket information
    end
else
    sock=-1;
    hdr = getSynthDataHeader;
end

% Durations
sampleDurationS = 1;
timeStartS = 0;
experimentDurationS = 60;
calibrationDurationS = 15;
maxFrequencyHz = 40; % Maximum frequency to be shown in the time-frequency plots

calibrationAnalysisDurationS = [5 15]; % Also used for eye open analysis
eyeCloseAnalysisDurationS  = [25 55];

% TimeVals
Fs = hdr.Fs; % sampling period of the EEG device.
timeValsS = 0:1/Fs:sampleDurationS-1/Fs;

% Initialization for the soundtone feedback
smoothKernel    = repmat(1/10,1,5);
epochsToAvg     = length(smoothKernel);

Fsound          = 44100;  % need a high enough value so that alpha power below baseline can be played
Fc              = 1000;
Fi              = 500;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Run the main loop %%%%%%%%%%%%%%%%%%%%%%%%%
while 1
    
    alphaRange = [str2double(get(hAlphaMin,'string')) str2double(get(hAlphaMax,'string'))];
    sessionNum = str2double(get(hSessionNum,'string'));
    trialNum = str2double(get(hTrialNum,'string'));
    
    if state == 0 % Idle state
        timeStartS = 0; % don't do anything
        
    elseif state<=3 % Start, Calibrate or Run
        
        if (state==2) % Calibration
            % Calibration should be done once for each session. If trialNum>1,
            % then first confirm if the calibration needs to be done again,
            % because in that case the trials have to be redone.
            if trialNum>1
                reply=input('If you run calibration you will have to run all trials in this session again. Continue? [y/n]: ','s');
                if strcmpi(reply,'y')
                    set(hTrialNum,'String','1'); % set trialNum to 1
                else
                    state=0;
                end
            end
        elseif (state==3) % Run experiment
            saveCalibrationFilename = fullfile(folderName,[subjectName 'CalibrationProcessedDataSession' num2str(sessionNum) '.mat']); % Look for calibration file
            if ~exist(saveCalibrationFilename,'file')
                disp('You need to first run calibration for this session...');
                state=0;
            else
                calibrationData = load(saveCalibrationFilename);
                calibrationVal = calibrationData.calibrationVal;
            end
        end
        
        if state>0
            if state==3 % Run
                displayRangeS=[0 experimentDurationS];
            else
                displayRangeS=[0 calibrationDurationS];
            end
            
            % Get Data, Power and alphaPos
            [rawDataTMP,signalLims,cLims] = getRawData(sock,hdr,sampleDurationS);
            [power,freqVals] = getPower(rawDataTMP,Fs,maxFrequencyHz);
            alphaPos = intersect(find(freqVals>=alphaRange(1)),find(freqVals<=alphaRange(2)));
            
            if timeStartS==0 % Initialize
                rawData = []; timeVals = [];
                tfData = []; timeValsTF = [];
                cla(hRawTrace);
                cla(hTF);
            end
            
            timeVals = cat(2,timeVals,timeStartS+timeValsS);
            rawData = cat(2,rawData,rawDataTMP);
            timeValsTF = cat(2,timeValsTF,timeStartS+sampleDurationS/2);
            tfData = cat(2,tfData,power);
            
            % Display Raw Signal
            plotData(hRawTrace,hTF,timeVals,rawData,timeValsTF,freqVals,log10(tfData),alphaRange,displayRangeS,signalLims,cLims);

            timeStartS = timeStartS+sampleDurationS;
            
            if state==3 % Run
                trialType = trialTypeList(sessionNum,trialNum);
                changeInAlphaPower = 10*(log10(mean(power(alphaPos)))-calibrationVal);
                
                % Generate feedback
                if trialType==1 % valid
                    stFreq = round(Fc + changeInAlphaPower* Fi);
                    
                elseif trialType==2 % invalid
                elseif trialType==3 % constant
                end
                soundTone = sine_tone(Fsound ,1,stFreq);
                sound(soundTone,Fsound);
                
                if timeStartS==calibrationDurationS % Ask subject to close eyes and relax
                    disp('Ask subject to close eyes');
                    
                elseif timeStartS==experimentDurationS % Save Data
                    timePosAnalysis = intersect(find(timeValsTF>=eyeCloseAnalysisDurationS(1)),find(timeValsTF<=eyeCloseAnalysisDurationS(2)));
                    
                    % Save raw data
                    saveRawFilename = fullfile(folderName,[subjectName 'RawDataSession' num2str(sessionNum) 'Trial' num2str(trialNum) '.mat']);
                    save(saveRawFilename,'rawData','timeVals');
                    
                    % Save processed data
                    alphaPower = tfData(alphaPos,timePosAnalysis);
                    meanChangeInAlphaPowerdB = 10*(mean(log10(mean(alphaPower,1)))-calibrationVal);
                    saveProcessedFilename = fullfile(folderName,[subjectName 'ProcessedDataSession' num2str(sessionNum) 'TrialNum' num2str(trialNum) '.mat']);
                    save(saveProcessedFilename,'tfData','timeValsTF','freqVals','alphaPos','timePosAnalysis','meanChangeInAlphaPower');
                    
                    % Display the score
                    disp(meanChangeInAlphaPowerdB);
                    
                    % Change trialNum and sessionNum
                    [nextSessionNum,nextTrialNum] = getNextTrialAndSession(trialTypeList,sessionNum,trialNum);
                    set(hSessionNum,'String',num2str(nextSessionNum));
                    set(hTrialNum,'String',num2str(nextTrialNum));
                    
                    % Update Analysis Figures
                    analysisPlotHandles = biofeedbackAnalysis(subjectName,analysisPlotHandles);
                    state=0;
                end
            else
                if timeStartS==calibrationDurationS
                    if (state==1)
                        timeStartS = 0;
                    elseif (state==2)
                        timePosCalibration = intersect(find(timeValsTF>=calibrationAnalysisDurationS(1)),find(timeValsTF<=calibrationAnalysisDurationS(2)));
                        
                        % Save raw data
                        saveRawFilename = fullfile(folderName,[subjectName 'CalibrationRawDataSession' num2str(sessionNum) '.mat']);
                        save(saveRawFilename,'rawData','timeVals');
                        
                        % Save processed data
                        alphaPower = tfData(alphaPos,timePosCalibration);
                        calibrationVal = mean(log10(mean(alphaPower,1)));
                        saveProcessedFilename = fullfile(folderName,[subjectName 'CalibrationProcessedDataSession' num2str(sessionNum) '.mat']);
                        save(saveProcessedFilename,'tfData','timeValsTF','freqVals','alphaPos','timePosCalibration','calibrationVal');
                        state=0;
                    end
                end
            end
        end
         
    elseif state == 4 % Exit the Experiment
        if sock ~=-1
            rda_close(sock);
        end
        clf;
    end
    drawnow;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   Callbacks  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Callback functions

    function Callback_StartStop(~,~)
        if hStartStop.Value==1 % Run
            state = 1;
            set(hStartStop,'String','stop');
        else                   % Stop
            state = 0;
            set(hStartStop,'String','start');
        end
    end

    function Callback_Calibrate(~,~)
        state = 2;
    end

    function Callback_Run(~,~)
        state = 3;
    end

    function Callback_Exit(~,~)
        state = 4;
    end
end

function [trialTypeList,folderName,sessionNum,trialNum] = createExperiment(subjectName)
%%%%%%%%%%%%%%%%%%%%%%%%% Setup the Experiment %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The details of each experiment are set up unfront and saved, so that they
% can be retrived later on in case the program crashes

% Data is saved in the Data folder in the parent directory
pathStr = fileparts(pwd);
folderName = fullfile(pathStr,'Data',subjectName);
if ~exist(folderName,'file')
    mkdir(folderName);
end

% Details of trial Types are stored in the following mat file
trialTypeFileName = fullfile(folderName,[subjectName 'trialTypeList.mat']);

if exist(trialTypeFileName,'file')
    disp(['Loading file... ' trialTypeFileName]);
    load(trialTypeFileName);
    [sessionNum,trialNum] = getExperimentProgress(subjectName,folderName);
else
    % Create TrialTypeList
    trialTypeList = createTrialTypeList;
    save(trialTypeFileName,'trialTypeList');
    sessionNum=1;trialNum=1;
end
end
function trialTypeList = createTrialTypeList
% Each trial is of three types
% 1 - valid tone
% 2 - invalid tone
% 3 - constant tone

numSessions = 5;
trialsPerSession = 12;

% In the first session, we have 75% valid and 25% constant tones
trialTypeTMP = [(1+zeros(1,round(0.75*trialsPerSession))) (3+zeros(1,round(0.25*trialsPerSession)))];
trialTypeList = trialTypeTMP(randperm(trialsPerSession));

for i=2:numSessions
    
    % In the remaining sessions, we have 50% valid, 25% invalid and 25% constant tones
    trialTypeTMP = [(1+zeros(1,round(0.5*trialsPerSession))) (2+zeros(1,round(0.25*trialsPerSession))) (3+zeros(1,round(0.25*trialsPerSession)))];
    trialTypeList = cat(1,trialTypeList,trialTypeTMP(randperm(trialsPerSession)));
end
end
function [rawData,signalLims,cLims]=getRawData(sock,hdr,sampleDurationS)
Fs = hdr.Fs;
nChans = hdr.nChans;  % The channels from which data is extracted

if sock==-1
    rawData = rand(nChans,sampleDurationS*Fs)-0.5;
    signalLims = [-0.5 0.5]; 
    cLims = [0 1];
    pause(1);
else
    rawData = rda_message(sock,hdr); % Get Data for 1 second
end
end
function hdr = getSynthDataHeader
hdr.Fs=500;
hdr.nChans=5;
end
function plotData(hRawTrace,hTF,timeToPlot,signalToPlot,timeToPlotTF,freqVals,powerToPlot,alphaRange,displayTimeRange,signalLims,cLims)
plot(hRawTrace,timeToPlot,mean(signalToPlot,1));
imagesc(hTF,timeToPlotTF,freqVals,powerToPlot);
axis(hRawTrace,[displayTimeRange signalLims]);
xlim(hTF,displayTimeRange);
set(hTF,'YDir','normal');
%caxis(hTF,cLims);
end