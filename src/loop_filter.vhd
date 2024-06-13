------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
--  _______                             ________                                            ______
--  __  __ \________ _____ _______      ___  __ \_____ _____________ ______ ___________________  /_
--  _  / / /___  __ \_  _ \__  __ \     __  /_/ /_  _ \__  ___/_  _ \_  __ `/__  ___/_  ___/__  __ \
--  / /_/ / __  /_/ //  __/_  / / /     _  _, _/ /  __/_(__  ) /  __// /_/ / _  /    / /__  _  / / /
--  \____/  _  .___/ \___/ /_/ /_/      /_/ |_|  \___/ /____/  \___/ \__,_/  /_/     \___/  /_/ /_/
--          /_/
--                   ________                _____ _____ _____         _____
--                   ____  _/_______ __________  /____(_)__  /_____  ____  /______
--                    __  /  __  __ \__  ___/_  __/__  / _  __/_  / / /_  __/_  _ \
--                   __/ /   _  / / /_(__  ) / /_  _  /  / /_  / /_/ / / /_  /  __/
--                   /___/   /_/ /_/ /____/  \__/  /_/   \__/  \__,_/  \__/  \___/
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
-- Copyright
------------------------------------------------------------------------------------------------------
--
-- Copyright 2024 by M. Wishek <matthew@wishek.com>
--
------------------------------------------------------------------------------------------------------
-- License
------------------------------------------------------------------------------------------------------
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2.
--
-- You may redistribute and modify this source and make products using it under
-- the terms of the CERN-OHL-W v2 (https://ohwr.org/cern_ohl_w_v2.txt).
--
-- This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
-- OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
-- Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: TBD
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on this
-- source, You must maintain the Source Location visible on the external case of
-- the products you make using this source.
--
------------------------------------------------------------------------------------------------------
-- Block name and description
------------------------------------------------------------------------------------------------------
--
-- This block provides a PI Loop Filter for the MSK Demodulator Costas Loop.
--
-- Documentation location: TBD
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------
-- ╦  ┬┌┐ ┬─┐┌─┐┬─┐┬┌─┐┌─┐
-- ║  │├┴┐├┬┘├─┤├┬┘│├┤ └─┐
-- ╩═╝┴└─┘┴└─┴ ┴┴└─┴└─┘└─┘
------------------------------------------------------------------------------------------------------
-- Libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;


------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY loop_filter IS 
	GENERIC (
		NCO_W 			: NATURAL := 32;
		ERR_W 			: NATURAL := 16;
		GAIN_W  		: NATURAL := 16;
		INVERT_FADJ 	: BOOLEAN := False;
		MAX_ACC_POS 	: SIGNED  := SHIFT_LEFT(to_signed(1,NCO_W), NCO_W-2);
		MAX_ACC_NEG 	: SIGNED  := SHIFT_LEFT(to_signed(1,NCO_W), NCO_W-1)
	);
	PORT (
		clk 			: IN  std_logic;
		init 			: IN  std_logic;

		enable 			: IN  std_logic;

		lpf_p_gain 		: IN  std_logic_vector(GAIN_W -1 DOWNTO 0);
		lpf_i_gain 		: IN  std_logic_vector(GAIN_W -1 DOWNTO 0);
		lpf_freeze 	 	: IN  std_logic;
		lpf_zero 		: IN  std_logic;	

		lpf_err_valid 	: IN  std_logic;
		lpf_err 		: IN  std_logic_vector(ERR_W -1 DOWNTO 0);

		lpf_adj_valid   : OUT std_logic;
		lpf_adjust		: OUT std_logic_vector(NCO_W -1 DOWNTO 0)
	);
END ENTITY loop_filter;


------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE rtl OF loop_filter IS 

	SIGNAL i_sum : signed(NCO_W -1 DOWNTO 0);
	SIGNAL i_sat : signed(NCO_W -1 DOWNTO 0);
	SIGNAL i_acc : signed(NCO_W -1 DOWNTO 0);
	SIGNAL i_val : signed(NCO_W -1 DOWNTO 0);
	SIGNAL p_val : signed(ERR_W -1 DOWNTO 0);

	SIGNAL lpf_err_valid_d  : std_logic;

	SIGNAL acc : signed(NCO_W -1 DOWNTO 0);
	SIGNAL sum : signed(NCO_W -1 DOWNTO 0);

BEGIN

------------------------------------------------------------------------------------------------------
--        ___  __  __   __                   __       
-- | |\ |  |  |_  / _  |__)  /\  |      /\  |__) |\/| 
-- | | \|  |  |__ \__) | \  /--\ |__   /--\ | \  |  | 
--                                                    
------------------------------------------------------------------------------------------------------
-- Integral Arm

	i_sum <= i_acc + resize(signed(lpf_err), NCO_W);

	i_sat <= MAX_ACC_POS WHEN i_sum(NCO_W -1) = '0' AND i_sum(NCO_W -2) = '1' ELSE
			 MAX_ACC_POS WHEN i_sum(NCO_W -1) = '1' AND i_sum(NCO_W -2) = '0' ELSE
			 i_sum;

	integral_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF enable = '1' THEN

				lpf_err_valid_d <= lpf_err_valid;

				IF lpf_err_valid = '1' AND lpf_freeze = '0' THEN
					i_acc <= i_sat;
					i_val <= resize(shift_right(i_acc * signed(lpf_i_gain), 8), NCO_W);
				END IF;

				IF lpf_zero = '1' OR init = '1' THEN
					i_acc <= (OTHERS => '0');
					i_val <= (OTHERS => '0');
				END IF;

			END IF;

			IF init = '1' THEN
				lpf_err_valid_d <= '0';
				i_acc			<= (OTHERS => '0');
				i_val 			<= (OTHERS => '0');
			END IF;

		END IF;
	END PROCESS integral_proc;


------------------------------------------------------------------------------------------------------
--  __   __   __   __   __   __  ___    __                        __       
-- |__) |__) /  \ |__) /  \ |__)  |  | /  \ |\ |  /\  |      /\  |__) |\/| 
-- |    | \  \__/ |    \__/ | \   |  | \__/ | \| /--\ |__   /--\ | \  |  | 
--                                                                         
------------------------------------------------------------------------------------------------------
-- Proportional Arm

	proportional_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF enable = '1' THEN

				IF lpf_err_valid = '1' THEN
					p_val <= resize(shift_right(signed(lpf_p_gain) * signed(lpf_err), 4), ERR_W);
				END IF;

			END IF;

			IF init = '1' THEN
				p_val <= (OTHERS => '0');
			END IF;

		END IF;
	END PROCESS proportional_proc;


------------------------------------------------------------------------------------------------------
--  __       __                            __       ___  __       ___ 
-- |__) |   (_  /  \ |\/|    _   _   _|   /  \ /  \  |  |__) /  \  |  
-- |    |   __) \__/ |  |   (_| | ) (_|   \__/ \__/  |  |    \__/  |  
--                                                                    
------------------------------------------------------------------------------------------------------
-- PI Sum and Ouput

	sum_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF enable = '1' THEN

				IF lpf_err_valid_d = '1' THEN
					IF INVERT_FADJ THEN
						lpf_adjust <= std_logic_vector(NOT (p_val + i_val) + 1);
					ELSE
						lpf_adjust <= std_logic_vector(p_val + i_val);
					END IF;
					lpf_adj_valid <= '1';
				ELSE
					lpf_adj_valid <= '0';
				END IF;

			END IF;

			IF init = '1' THEN
				lpf_adjust 		<= (OTHERS => '0');
				lpf_adj_valid	<= '0';
			END IF;

		END IF;
	END PROCESS sum_proc;

END ARCHITECTURE rtl;
