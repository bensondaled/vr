function code = ea_tmaze
    code.initialization = @initializationCodeFun;
    code.runtime = @runtimeCodeFun;
    code.termination = @terminationCodeFun;

function vr = initializationCodeFun(vr)
    % constants
    vr.START = 1;
    vr.CUE = 2;
    vr.DELAY = 3;
    vr.DECISION = 4;
    vr.REWARD = 5;
    vr.ITI = 6;
    vr.LEFT = 1;
    vr.RIGHT = 2;
    logPath = 'C:\Users\tankadmin\Desktop\virmenLogs_deverett\';
    vr.expName = inputdlg('Experiment name:', 'Experiment Name', 1, datestr(now, 'yyyymmdd_HHMMSS'));
    
    % parameters
    vr.startPosition = 0.0;
    vr.itiCorrect = 3; %seconds
    vr.itiIncorrect = 5; %seconds
    vr.rewardDuration = 5; %seconds
    trialLambdas = [8,2 ; 9,1]; %left/right lambda of poisson process
    trialFreqs = [50, 50]; %number of each type of trial
    vr.nTrials = sum(trialFreqs);
    
    % external interactions
    beep on;
    vr = initDAQ(vr);
    vr.fid = fopen(strcat(logPath, vr.expName), 'w');
    vr.text(1).position = [-1.2 1]; % upper-left corner of the screen 
    vr.text(1).size = 0.03; % letter size as fraction of the screen 
    vr.text(1).color = [1 1 0]; % yellow
    
    % VR world variables
    vr.hallWidth = eval(vr.exper.variables.hallWidth);
    vr.wallHeight = eval(vr.exper.variables.wallHeight);
    vr.boundStartEdge = eval(vr.exper.variables.borderStartEdge);
    vr.phaseLenStart = eval(vr.exper.variables.phaseLenStart);
    vr.phaseLenCue = eval(vr.exper.variables.phaseLenCue);
    vr.phaseLenDelay = eval(vr.exper.variables.phaseLenDelay);
    vr.decisionLength = eval(vr.exper.variables.decisionWidth);
    vr.rewardLength = eval(vr.exper.variables.rewardWidth);
    % calculations from those
    vr.boundStartCue = vr.boundStartEdge + vr.phaseLenStart;
    vr.boundCueDelay = vr.boundStartCue + vr.phaseLenCue;
    vr.boundDelayDecision = vr.boundCueDelay + vr.phaseLenDelay;
    vr.boundDecisionRewardL = 0 - vr.decisionLength/2.0;
    vr.boundDecisionRewardR = 0 + vr.decisionLength/2.0;
    
    % trials
    vr.trials = generateTrials(vr, trialLambdas, trialFreqs);

    % dynamic variables
    vr.phase = vr.START;
    vr.phasesComplete = [];
    vr.trialsDone = 0;
    vr.elapsedInPhase = 0.0;
    vr.iti = vr.itiIncorrect;
    vr.currentTrial = vr.trials(1);
    vr = displayCurrentTrial(vr);

    % init code
    save(strcat(logPath, vr.expName, '_vr_backup'), 'vr')
    vr.position(2) = vr.startPosition;

function vr = runtimeCodeFun(vr)
    lastPhase = vr.phase;
    vr.phase = determinePhase(vr);
    
    if (vr.phase ~= lastPhase)
        switch lastPhase %%% code for ending a phase
            case vr.START ;
            case vr.CUE ;
            case vr.DELAY ;
            case vr.DECISION ;
            case vr.REWARD
                vr.worlds{vr.currentWorld}.surface.visible(:) = false; % make whole world black
            case vr.ITI
                if (vr.trialsDone == vr.nTrials)
                   vr.experimentEnded = true; 
                else
                    vr.trialsDone += 1;
                    vr.phasesComplete = [];
                    vr.currentTrial = vr.trials(vr.trialsDone+1);
                    vr.position(2)=vr.startPosition; vr.dp(:)=0; % teleport to start
                    vr = displayCurrentTrial(vr);
                end
        end
        vr.phasesComplete = [vr.phasesComplete lastPhase];
        vr.elapsedInPhase = 0.0;
        switch vr.phase %%% init for a new phase
            case vr.START ;
                % if adding anything here, needs to be under condition: if (vr.trialsDone ~= vr.nTrials)
            case vr.CUE ;
            case vr.DELAY ;
            case vr.DECISION ;
            case vr.REWARD
                if ( (vr.position(1) < vr.boundDecisionRewardL && vr.trials(vr.currentTrial).correct == vr.LEFT) ...
                    || (vr.position(1) > vr.boundDecisionRewardR && vr.trials(vr.currentTrial).correct == vr.RIGHT) )
                    % ** give reward
                    vr.iti = vr.itiCorrect;
                else
                    vr.iti = vr.itiIncorrect;
                end
            case vr.ITI ;
        end
    else %%% continuing in same phase
        switch vr.phase
            case vr.START ;
            case vr.CUE ;
            case vr.DELAY ;
            case vr.DECISION ;
            case vr.REWARD ;
            case vr.ITI ;
        end
    end
    updateDAQ(vr);
    logIteration(vr);
    vr.text(1).string = ['TIME ' datestr(now-vr.startTime,'MM.SS') ; 'PHASE ' vr.phase];
    vr.elapsedInPhase += vr.dt;

function vr = terminationCodeFun(vr)
    stop(vr.ai); % daq
    delete(vr.tempfile); % daq
    fclose(vr.fid);

%%%% Other Functions %%%%%

function logIteration(vr)
    fwrite(vr.fid, [now, vr.position vr.velocity vr.currentTrial.index vr.phase], 'double');
end

function phase = determinePhase(vr)
    ypos = vr.position(2);
    xpos = vr.position(1);
    phase = vr.phase;
    if (phase == vr.START && ypos >= vr.boundStartCue && ypos < vr.boundCueDelay)
        phase = vr.CUE;
    elseif (phase == vr.CUE && ypos >= vr.boundCueDelay && ypos < vr.boundDelayDecision)
        phase = vr.DELAY;
    elseif (phase == vr.DELAY && ypos >= vr.boundDelayDecision && (xpos > vr.boundDecisionRewardL && xpos < vr.boundDecisionRewardR))
        phase = vr.DECISION;
    elseif (phase == vr.DECISION && ypos >= vr.boundDelayDecision && (xpos < vr.boundDecisionRewardL || xpos > vr.boundDecisionRewardR))
        phase = vr.REWARD;
    elseif (phase == vr.REWARD && vr.elapsedInPhase >= vr.rewardDuration)
        phase = vr.ITI;
    elseif (phase == vr.ITI && vr.elapsedInPhase >= vr.iti)
        phase = vr.START;
end

function trials = generateTrials(vr, lambdas, freqs)
    trials = [];
    for t = 1:numel(freqs)
        for tt = 1:freqs(t)
            valid = false;
            while (valid == false)
                valid = true;
                trial = {};
                
                posL = [];
                while (sum(posL) < 1.0)
                    posL = [posL exprnd(1./lambdas(t,vr.LEFT))];
                end
                posL = posL(1:end-1);
                posL = cumsum(posL);
                posR = [];
                while (sum(posR) < 1.0)
                    posR = [posR exprnd(1./lambdas(t,vr.RIGHT))];
                end
                posR = posR(1:end-1);
                posR = cumsum(posR);

                trial.posL = posL;
                trial.posR = posR;
                trial.lambdas = lambdas(t,:);
                if (numel(posL) > numel(posR))
                    trial.correct = vr.LEFT;
                elseif (numel(posR) > numel(posR))
                    trial.correct = vr.RIGHT;
                else
                    valid = false;
                end
            end
            trials = [trials trial];
        end
    end
    %theoretically shuffle here
    for t = 1:numel(trials)
        trials(t).index = t;
    end
end

function vr = initDAQ(vr)
    daqreset;
    vr.ai = analoginput('nidaq', 'dev1')
    addchannel(vr.ai, 0:1)
    set(vr.ai,'samplerate',1000,'samplespertrigger',inf);
    set(vr.ai,'bufferingconfig',[8 100]);
    set(vr.ai,'loggingmode','Disk'); 
    vr.tempfile = [tempname '.log']; 
    set(vr.ai,'logfilename',vr.tempfile);
    start(vr.ai);
end

function vr = displayCurrentTrial(vr)
    return;
    %NOTES: check whether an object made in GUI, ex. cueCylinder, if it has multiple positions, how that shows up in the vr.worlds{}.objects.vertices/indices field. If it's clearly multiple instances with separate positions, then it will be easy to manipulate them in run time. When you go to make the actual pillars, do it programatically, not with gui, and set something like 1000 positions for them on each side, so that you never have to add a new object during runtime for any trial. all unused ones can be made transparent.
    
    %determine the pillar positions for this trial, and the shift that needs to get them there from last trial
    trial = vr.currentTrial;
    trialIdx = vr.currentTrial.index;
    posL = trial.posL * vr.phaseLenCue;
    if trialIdx ~= 1
       lastTrial = vr.trials(vr.currentTrial.index-1);
       lastPosL = lastTrial.posL * vr.phaseLenCue;
    else
       lastPosL = zeros(size(posL));
    end
    shiftL = posL - lastPosL(1:numel(posL));
   
    %move the pillars
    idxL = vr.worlds{vr.currentWorld}.objects.indices.cueCylinderL;
    verticesL = vr.worlds{vr.currentWorld}.objects.vertices(idxL,:); %here's where I need to look for structure. This should maybe be 3D when there are multiple instances of an object?
    verticesL = verticesL(1):verticesL(2);
    yL = vr.worlds{vr.currentWorld}.surface.vertices(2, vr.verticesL);
    vr.worlds{vr.currentWorld}.surface.vertices(2, vr.verticesL) = yL + shiftL; %change position
    vr.worlds{vr.currentWorld}.surface.colors(4, vr.verticesL) = 0; %change transparency THIS IS NOT DONE
end
