% This program is used to analysize the results of the alpha feedback project.
% Input - subjectName: A string to identify the subject.

function analysisPlotHandles = biofeedbackAnalysis(subjectName,analysisPlotHandles)

if ~exist(subjectName,'var');   subjectName='';                         end

% Getting plot handles if they don't exist
if ~exist(analysisPlotHandles,'var');
    analysisPlotHandles.powerVsTrial  = subplot('Position',[0.05 0.3 0.4 0.2]);
    analysisPlotHandles.diffPowerVsTrial = subplot('Position',[0.05 0.05 0.4 0.2]);
    analysisPlotHandles.powerVsTime   = subplot('Position',[0.55 0.3 0.4 0.2]);
    analysisPlotHandles.barPlot   = subplot('Position',[0.55 0.05 0.4 0.2]);
end

% Load saved data
pathStr = fileparts(pwd);
folderName = fullfile(pathStr,'Data',subjectName);
summaryFileName = fullfile(folderName,[subjectName 'RecordingDetails.mat']);
recordingDetails = load(summaryFileName,'recordingDetails');

trialTypeList = recordingDetails(3,:);

numTotalTrials = length(sessionNumList);

powerVsTimeList = []; % Alpha Power as a function of time
meanEyeOpenPowerList = []; % Mean alpha power during Eye Open condition
semEyeOpenPowerList = []; % sem of alpha power during Eye Open condition
meanEyeClosedPowerList = []; % Mean alpha power during Eye Closed condition
semEyeClosedPowerList = []; % sem of alpha power during Eye Closed condition

for i=1:numTotalTrials
    analysisData = load(fullfile(folderName,[subjectName 'session' trialNumList(i) 'trial' trialTypeList(i) 'AnalysisData.mat']));
    powerVsTimeList = cat(1,powerVsTimeList,analysisData.powerVsTime);
    meanEyeOpenPowerList = cat(2,meanEyeOpenPowerList,analysisData.meanEyeOpenPower);
    semEyeOpenPowerList = cat(2,semEyeOpenPowerList,analysisData.semEyeOpenPower);
    meanEyeClosedPowerList = cat(2,meanEyeClosedPowerList,analysisData.meanEyeClosedPower);
    semEyeClosedPowerList = cat(2,semEyeClosedPowerList,analysisData.semEyeClosedPower);
end

% Plot Data
colorNames = 'rgb';
hold(analysisPlotHandles.powerVsTrial,'on');
for i=1:3 % Trial Type
    trialPos = find(trialTypeList==i);
    errorbar(analysisPlotHandles.powerVsTrial,trialPos,meanEyeOpenPowerList(trialPos),semEyeOpenPowerList(trialPos),'color',colorNames(i));
    errorbar(analysisPlotHandles.powerVsTrial,trialPos,meanEyeClosedPowerList(trialPos),semEyeClosedPowerList(trialPos),'color',colorNames(i));
    
    pVsT = powerVsTime;
end
drawnow;
end