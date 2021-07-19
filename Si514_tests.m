%% SI514 test script
% run the following sections to see different operating modes of the Si514 class
clear all

%% Setting base frequency
s=Si514(10e6)

%% Manually setting the parameters
s=Si514();
s.M_int=65;
s.M_frac=21824021;
s.HS_DIV=650;
s.LS_DIV=5;
s.LP1=2;
s.LP2=2;
fprintf('Resulting frequency is: %.3f Hz\n', s.frequency)

%% Using register values
regs=[51 163 57 104 203 8 18 0 0 0 1];
s=Si514([], regs)

%% battery test using table from the datasheet
battery = [	0.1			65.04065041	65	21824021	650		5	2	2
			1.544		65.08167605	65	43849494	674		1	2	2
			2.048		65.06466542	65	34716981	1016	0	2	2
			4.096		65.06466542	65	34716981	508		0	2	2
			4.9152		65.16712946	65	89726943	424		0	2	2
			19.44		65.65103189	65	349520087	108		0	2	3
			24.576		66.08930582	66	47945695	86		0	2	3
			25			65.66604128	65	357578187	84		0	2	3
			27			65.85365854	65	458304437	78		0	2	3
			38.88		65.65103189	65	349520087	54		0	2	3
			44.736		67.14596623	67	78365022	48		0	2	3
			54			67.54221388	67	291098862	40		0	2	3
			62.5		66.44777986	66	240399983	34		0	2	3
			65.536		65.57698562	65	309766794	32		0	2	3
			74.175824	69.58332458	69	313169998	30		0	3	3
			74.25		69.65290807	69	350527350	30		0	3	3
			77.76		68.08255159	68	44319550	28		0	3	3
			106.25		66.44777986	66	240399983	20		0	2	3
			125			70.3564728	70	191379875	18		0	3	3
			148.351648	74.22221288	74	119299633	16		0	3	4
			148.5		74.29643527	74	159147475	16		0	3	4
			150			65.66604128	65	357578187	14		0	2	3
			155.52		68.08255159	68	44319550	14		0	3	3
			156.25		68.40212633	68	215889929	14		0	3	3
			212.5		66.44777986	66	240399983	10		0	2	3
			250			78.17385866	78	93339658	10		0	4	4];

% params + M to frequency
fprintf('\n=== Params + M to Frequency Test ===\n')
for k=1:size(battery,1)
    s=Si514();
    s.M=battery(k,2);
    s.HS_DIV=battery(k,5);
    s.LS_DIV=battery(k,6);
    s.LP1=battery(k,7);
    s.LP2=battery(k,8);
    ferr=abs(s.frequency-battery(k,1)*1e6);
    fprintf('Expected %7.3f MHz, frequency error %.3f Hz\n', battery(k,1), ferr);
end

% Frequency to params + M
fprintf('\n=== Frequency to Params Test ===\n')
for k=1:size(battery,1)
    s=Si514(battery(k,1)*1e6);
    err(1) = s.HS_DIV ~= battery(k,5);
    err(2) = s.LS_DIV ~= battery(k,6);
    err(3) = s.LP1 ~= battery(k,7);
    err(4) = s.LP2 ~= battery(k,8);
    err(5) = s.M_int ~= battery(k,3);
    err(6) = abs(s.M_frac - battery(k,4)) > 1;
    ferr=abs(s.frequency-battery(k,1)*1e6);
    fprintf('Frequency %7.3f MHz, frequency error %.3f Hz, params errors: %d\n', battery(k,1), ferr, sum(err));
end
