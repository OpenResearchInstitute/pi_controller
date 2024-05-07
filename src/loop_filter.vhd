


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY loop_filter IS 
	GENERIC (
		NCO_W 			: NATURAL := 32;
		ERR_W 			: NATURAL := 16;
		GAIN_W  		: NATURAL := 16
	);
	PORT (
		clk 			: IN  std_logic;
		init 			: IN  std_logic;

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

ARCHITECTURE rtl OF loop_filter IS 

	SIGNAL i_acc : signed(NCO_W -1 DOWNTO 0);
	SIGNAL i_val : signed(NCO_W -1 DOWNTO 0);
	SIGNAL p_val : signed(ERR_W -1 DOWNTO 0);
	SIGNAL lpf_err_valid_d : std_logic;

BEGIN

	integral_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			lpf_err_valid_d <= lpf_err_valid;

			IF lpf_err_valid = '1' AND lpf_freeze = '0' THEN
				i_acc <= i_acc + signed(lpf_err);
				i_val <= resize(i_acc * signed(lpf_i_gain), NCO_W);
			END IF;

			IF lpf_zero = '1' OR init = '1' THEN
				i_acc <= (OTHERS => '0');
				i_val <= (OTHERS => '0');
			END IF;

		END IF;
	END PROCESS integral_proc;

	proportional_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF lpf_err_valid = '1' THEN
				p_val <= resize(signed(lpf_p_gain) * signed(lpf_err), ERR_W);
			END IF;

		END IF;
	END PROCESS proportional_proc;

	sum_proc : PROCESS (clk)
	BEGIN
		IF clk'EVENT AND clk = '1' THEN

			IF lpf_err_valid_d = '1' THEN
				lpf_adjust <= std_logic_vector(p_val + i_val);
				lpf_adj_valid <= '1';
			ELSE
				lpf_adj_valid <= '0';
			END IF;

		END IF;
	END PROCESS sum_proc;

END ARCHITECTURE rtl;