classdef Si514 < handle
% SI514 Matlab Class for controlling Silabs Si514 programmable XO
%
% Syntax:
% Si514() create empty object.
% Si514(frequency) set desired oscillator output frequency.
% Si514(frequency, regs) set old registers and calculate the new desired
%   oscillator output frequency.
% Si514([], regs) set registers without specify a new frequency.
%
% (c) 2021 - AleR87

    properties(Dependent = true)
        frequency           % Oscillator output frequency
        regs                % Configuration Registers
        M                   % Feedback divider value
    end

    properties
        freq_cal = 0;
        LP1 = 0             % Loop compensation factor 1
        LP2 = 0             % Loop compensation factor 2
        LS_DIV = 0          % Last output divider factor
        HS_DIV = 0          % High speed output divider
        M_int = 0           % Integer part of feedback divider M
        M_frac = 0          % Fractional part of feedback divider M
        OE_STATE = 0        % Logic state of output when is disabled
        RST = 0             % Global Reset
        OE = 0              % Output Enable
        FCAL = 0            % Triggers frequency calibration cycle
    end

    properties(Access = private)
        regs_ = zeros(1,11,'uint8'); % Internal copy of Configuration Registers
    end

    properties(Access = private, Constant)
        FMIN = 100e3;
        FMAX = 250e6;
        FXO = 31980000;
        FVCO_MIN = 2080;
        FVCO_MAX = 2500;
        HS_DIV_MIN = 10;
        HS_DIV_MAX = 1022;
        M_MIN = [78.17385866, 75.843265046, 72.937624981, 67.859763463, ...
            65.259980246, 65.04065041];
        regs_MASK = {'0', '0', '0', '0', '0', '3F', '0', '73', '30', '80', '5'};
    end

    methods
        function obj=Si514(frequency, regs)
            % Si514(frequency, regs)

            if nargin >= 2
                obj.regs = regs;
            end
            if nargin >= 1 && ~isempty(frequency)
                obj.frequency = frequency;
            end
        end

        function newFreq = makeFrequencyStep(obj, delta_freq)
            % newFreq = makeFrequencyStep(obj, delta_freq)
            obj.frequency = obj.frequency + delta_freq;
            newFreq = obj.frequency;
        end

        function newFreq = makePeriodStep(obj, delta_period)
            % newFreq = makePeriodStep(obj, delta_period)
            obj.frequency = 1/(1/obj.frequency + delta_period);
            newFreq = obj.frequency;
        end


        % Get methods
        function val = get.frequency(obj)
            val = obj.calculateFreqFromParams();
        end

        function val = get.regs(obj)
            val = obj.calculateRegsFromParams();
        end

        function val = get.M(obj)
            val = obj.M_int + obj.M_frac/2^29;
        end

        % Set methods
        function set.frequency(obj, val)
            obj.validateInputNum(val, obj.FMIN, obj.FMAX);
            obj.calculateParamsFromFreq(val)
        end

        function set.freq_cal(obj, val)
            obj.freq_cal = obj.validateInputNum(val, obj.FMIN, obj.FMAX);
        end

        function set.regs(obj, val)
            obj.validateInputNums(val,11,0,255);
            obj.calculateParamsFromRegs(val);
            obj.regs_ = uint8(val);
        end

        function set.M(obj, val)
            obj.validateInputNum(val, obj.M_MIN(end), obj.M_MIN(1));
            obj.M_int = floor(val);
            obj.M_frac = (val-floor(val))*2^29;
        end

        function set.M_int(obj, val)
            obj.M_int = obj.validateInputNum(val, floor(obj.M_MIN(end)), ...
                                                  floor(obj.M_MIN(1)), true);
        end

        function set.M_frac(obj, val)
            obj.M_frac = obj.validateInputNum(val, 0, 2^29-1);
        end

        function set.LP1(obj, val)
            obj.LP1 = obj.validateInputNum(val, 0, 15, true);
        end

        function set.LP2(obj, val)
            obj.LP2 = obj.validateInputNum(val, 0, 15, true);
        end

        function set.HS_DIV(obj, val)
            obj.validateInputNum(val, 10, 1022, true);
            if rem(val, 2) ~= 0
                error('Input value %.0f must be an even number', val);
            end
            obj.HS_DIV = val;
        end

        function set.LS_DIV(obj, val)
            obj.LS_DIV = obj.validateInputNum(val, 0, 5, true);
        end

        function set.OE_STATE(obj, val)
            obj.OE_STATE = obj.validateInputNum(val, 0, 3, true);
        end

        function set.RST(obj, val)
            obj.RST = obj.validateInputTF(val);
        end

        function set.OE(obj, val)
            obj.OE = obj.validateInputTF(val);
        end

        function set.FCAL(obj, val)
            obj.FCAL = obj.validateInputTF(val);
        end
    end

    methods(Access = private)
        function calculateParamsFromFreq(obj, freq)
            obj.LS_DIV = nextpow2(ceil(obj.FVCO_MIN/(freq/1e6*obj.HS_DIV_MAX)));
            obj.HS_DIV = ceil(obj.FVCO_MIN/((freq * 2^obj.LS_DIV)/1e6)/2)*2;
            if obj.HS_DIV < obj.HS_DIV_MIN
                obj.HS_DIV = obj.HS_DIV_MIN;
            elseif obj.HS_DIV > obj.HS_DIV_MAX
                obj.HS_DIV = obj.HS_DIV_MAX;
            end
            if rem(obj.HS_DIV,2)
                obj.HS_DIV = obj.HS_DIV + 1;
            end

            M = 2^obj.LS_DIV * obj.HS_DIV * freq / obj.FXO;
            obj.M_int = floor(M);
            obj.M_frac = (M-obj.M_int)*2^29;

            if M > obj.M_MIN(2)
                obj.LP1 = 4;
                obj.LP2 = 4;
            elseif M > obj.M_MIN(3)
                obj.LP1 = 3;
                obj.LP2 = 4;
            elseif M > obj.M_MIN(4)
                obj.LP1 = 3;
                obj.LP2 = 3;
            elseif M > obj.M_MIN(5)
                obj.LP1 = 2;
                obj.LP2 = 3;
            else
                obj.LP1 = 2;
                obj.LP2 = 2;
            end

            if abs(freq-obj.freq_cal)/obj.freq_cal < 1000*1e-6
                obj.FCAL = false;
            else
                obj.FCAL = true;
                obj.freq_cal = freq;
            end
        end

        function freq = calculateFreqFromParams(obj)
            freq = obj.FXO*obj.M/(2^obj.LS_DIV*obj.HS_DIV);
        end

        function regs = calculateRegsFromParams(obj)
            % mask original regs
            regs = bitand(obj.regs_,bitcmp(uint8(hex2dec(obj.regs_MASK)))');

            % reg 0
            regs(1) = uint8(obj.LP1*16 + obj.LP2);
            % reg 5 - 6 - 7
            MfracInt = uint32(obj.M_frac);
            regs(2) = bitand(MfracInt, 255);
            regs(3) = bitand(bitshift(MfracInt, -8), 255);
            regs(4) = bitand(bitshift(MfracInt, -16), 255);
            % reg 8
            regs(5) = bitand(obj.M_int,7)*32;
            regs(5) = regs(5) + uint8(bitand(bitshift(MfracInt, -24), 31));
            % reg 9
            regs(6) = regs(6) + uint8(bitshift(obj.M_int, -3));
            % reg 10
            regs(7) = bitand(obj.HS_DIV, 255);
            % reg 11
            regs(8) = regs(8) + obj.LS_DIV*16 + uint8(bitshift(obj.HS_DIV, -8));
            % reg 14
            regs(9) = regs(9) + uint8(obj.OE_STATE*16);
        end

        function calculateParamsFromRegs(obj, regs)
            obj.LP1 = bitshift(regs(1), -4);
            obj.LP2 = bitand(regs(1), 15);
            obj.LS_DIV = bitand(bitshift(regs(8), -4), 7);
            obj.HS_DIV = bitand(regs(8), 3)*256 + regs(7);
            obj.M_int = bitand(regs(6), 63)*8 + bitshift(regs(5), -5);
            obj.M_frac = bitand(regs(5), 31)*2^24 + regs(4)*2^16 ...
                                                  + regs(3)*2^8 + regs(2);
            obj.OE_STATE = bitand(bitshift(regs(9), -4), 3);
            obj.RST = bitget(regs(10), 8);
            obj.OE = bitget(regs(11), 3);
            obj.FCAL = bitget(regs(11), 1);
        end
    end

    methods (Static, Access = private)
        function val = validateInputNum(val, min, max, integer)
            if nargin < 4
                integer = false;
            end
            if isnumeric(val) && numel(val) == 1
                if val < min || val > max
                    error(['Input value ' ...
                        num2str(val) ' must be between ' ...
                        num2str(min) ' and ' num2str(max)]);
                end
                if integer && (val ~= round(val))
                    error(['Input value ' num2str(val) ' must be an integer']);
                end
            else
                error('Input value must be a scalar number')
            end
        end

        function validateInputNums(val, theSize, min, max)
            if size(val) ~= theSize
                strSize = '';
                for k = 1:length(theSize)
                    strSize = [strSize num2str(theSize(k)) ' × ']; %#ok<AGROW>
                end
                error(['Size of the input array must be ' strSize(1:end-3)]);
            else
                for k = 1:numel(val)
                    Si514.validateInputNum(val(k), min, max);
                end
            end
        end

        function new_val=validateInputTF(val)
            if islogical(val)
                new_val=val;
            elseif isnumeric(val)
                if val == 0
                    new_val = false;
                elseif val == 1
                    new_val = true;
                else
                    error('Input value must be logical or 0/1');
                end
            else
                error('Input value must be logical');
            end
        end
    end
end
