function code = tmaze
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;

% INIT
function vr = initializationCodeFun(vr)

    % parameters
    vr.nTrials = 100;

    % constants
    vr.LONGARM = 0;
    vr.SHORTARM = 1;
    vr.TERMINATION_AREA = 2;
    
    vr.NAV = 0;
    vr.WAIT = 1;
    vr.REWARD = 2;
    vr.ITI = 3;

    vr.L = 1;
    vr.R = 2;

    % import gui variables
    vr.startPosition = [0, eval(vr.exper.variables.startPositionY), eval(vr.exper.variables.startPositionZ), 0];
    vr.trackLength = eval(vr.exper.variables.trackLength);
    vr.displaceShift = eval(vr.exper.variables.displaceShift);
    % walls
    idxWallL1 = vr.worlds{vr.currentWorld}.objects.indices.wallLeftRule1;
    idxWallL2 = vr.worlds{vr.currentWorld}.objects.indices.wallLeftRule2;
    idxWallR1 = vr.worlds{vr.currentWorld}.objects.indices.wallRightRule1;
    idxWallR2 = vr.worlds{vr.currentWorld}.objects.indices.wallRightRule2;
    v01WallL1 = vr.worlds{vr.currentWorld}.objects.vertices(idxWallL1,:);
    v01WallL2 = vr.worlds{vr.currentWorld}.objects.vertices(idxWallL2,:);
    v01WallR1 = vr.worlds{vr.currentWorld}.objects.vertices(idxWallR1,:);
    v01WallR2 = vr.worlds{vr.currentWorld}.objects.vertices(idxWallR2,:);
    vr.idxsWallL1 = v01WallL1(1):v01WallL1(2);
    vr.idxsWallL2 = v01WallL2(1):v01WallL2(2);
    vr.idxsWallR1 = v01WallR1(1):v01WallR1(2);
    vr.idxsWallR2 = v01WallR2(1):v01WallR2(2);

    % custom variables
    vr.terminationDistance = 0.7 * eval(vr.exper.variables.tWidth)/2;
    vr.waitDuration = 1.0;
    vr.rewardDuration = 1.0;
    vr.itiDuration = 2.0;

    % trials
    vr.trials = randi(2,vr.nTrials,1);

    % save paths
    vr.pathSeparator = '/'
    vr.path = '/Users/ben/Desktop/';
    vr.runName = datestr(now,'yyyymmddTHHMMSS');
    exper = copyVirmenObject(vr.exper);
    vr.savePathExp = [vr.path vr.pathSeparator vr.runName '.mat'];
    save(vr.savePathExp,'exper');
    vr.savePathDat = [vr.path vr.pathSeparator vr.runName '.dat'];
    vr.fid = fopen(vr.savePathDat,'w');
    fwrite(vr.fid,11,'double'); % the int represents number of fields being saved

    % runtime display
    vr.text(1).string = '0';
    vr.text(1).position = [-.14 .1];
    vr.text(1).size = .03;
    vr.text(1).color = [1 0 1];

    % runtime variables
    vr.runStart = now;
    vr.trialStart = now;
    vr.phaseStart = now;
    vr.currentLoc = vr.LONGARM;
    vr.currentPhase = vr.NAV;
    vr.trialIdx = 1;
    vr.rewarded = false;

    % initial conditions
    vr.currentRule = 1;
    vr = changeRule(vr, vr.trials(vr.trialIdx));

% RUNTIME
function vr = runtimeCodeFun(vr)

    trialEndResult = -1;

    ypos = vr.position(2);
    xpos = vr.position(1);

    cph = vr.currentPhase;
    cloc = vr.currentLoc;
    dtPhase = dt(now,vr.phaseStart);

    % determine position
    if (ypos < vr.trackLength)
        loc = vr.LONGARM;
    elseif (ypos >= vr.trackLength && abs(xpos) < vr.terminationDistance)
        loc = vr.SHORTARM;
    elseif (ypos >= vr.trackLength && abs(xpos) >= vr.terminationDistance)
        loc = vr.TERMINATION_AREA;
    end

    if (cloc ~= loc)
        if (cloc == vr.SHORTARM && loc == vr.TERMINATION_AREA)
            vr.phaseStart = now;
            vr.currentPhase = vr.WAIT;
        end
    end
    vr.currentLoc = loc;

    if (vr.currentPhase == vr.WAIT && dtPhase > vr.waitDuration)
        vr.phaseStart = now;
        vr.currentPhase = vr.REWARD;
    elseif (vr.currentPhase == vr.REWARD && dtPhase > vr.rewardDuration)
        % determine side they're on:
        side = (xpos > 0) + 1;
        % deliver reward if correct:
        if (side == vr.trials(vr.trialIdx))
            'reward'
            % DELIVER REWARD
            vr.rewarded = true;
        end

        vr.phaseStart = now;
        vr.currentPhase = vr.ITI;
        vr.worlds{vr.currentWorld}.surface.visible(:) = false; % make whole world black
    elseif (vr.currentPhase == vr.ITI && dtPhase > vr.itiDuration)
        trialEndResult = vr.rewarded;
        vr.currentPhase = vr.NAV;
        vr.trialStart = now;
        vr.trialIdx = vr.trialIdx + 1;
        vr.rewarded = false;
        vr = changeRule(vr, vr.trials(vr.trialIdx));
        vr = goToStart(vr);
        vr.worlds{vr.currentWorld}.surface.visible(:) = true; % make whole world visible
    end

    vr.text(1).string = ['TIME ' datestr(now-vr.runStart,'MM.SS')];
    tolog = [now vr.position vr.velocity vr.trialIdx trialEndResult];
    fwrite(vr.fid,tolog,'double');

% END
function vr = terminationCodeFun(vr)
    fclose all;
    fid = fopen(vr.savePathDat);
    data = fread(fid,'double');
    num = data(1);
    data = data(2:end);
    data = reshape(data,num,numel(data)/num);
    assignin('base','data',data);
    fclose all;
    
    answer = inputdlg({'Animal ID','Comment'},'Question',[1; 5]);
    if ~isempty(answer)
        comment = answer{2};
        save(vr.savePathExp,'comment','-append')
        if ~exist([vr.path vr.pathSeparator answer{1}],'dir')
            mkdir([vr.path vr.pathSeparator answer{1}]);
        end
        movefile(vr.savePathExp,[vr.path vr.pathSeparator answer{1} vr.pathSeparator vr.runName '.mat']);
        movefile(vr.savePathDat,[vr.path vr.pathSeparator answer{1} vr.pathSeparator vr.runName '.dat']);
    end
    
% OTHER
function vr = goToStart(vr)
    for i = 1:length(vr.position)
        vr.position(i) = vr.startPosition(i);
    end

function res = dt(t2,t1)
    res = etime(datevec(t2),datevec(t1));

function vr = changeRule(vr, rule)
    if (vr.currentRule == rule)
        return
    end

    shift = vr.displaceShift;
    if (rule==1)
        signn = 1;
    elseif (rule==2)
        signn = -1;
    end

    x_L1 = vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallL1);
    x_L2 = vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallL2);
    x_R1 = vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallR1);
    x_R2 = vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallR2);

    vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallL1) = x_L1 + signn*shift;
    vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallL2) = x_L2 - signn*shift;
    vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallR1) = x_R1 - signn*shift;
    vr.worlds{vr.currentWorld}.surface.vertices(1,vr.idxsWallR2) = x_R2 + signn*shift;

    vr.currentRule = rule;
