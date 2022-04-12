----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 04/05/2022 05:37:43 PM
-- Design Name:
-- Module Name: QpixAsicTb - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.QpixPkg.all;
use work.QpixProtoPkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity QpixAsicTb is
end QpixAsicTb;

architecture Behavioral of QpixAsicTb is

  -- constants for clocks and simulation
   constant CLK_PERIOD_NOMINAL_C           : time := 20833.0 ps; -- 48 MHz
   constant Zynq_CLK_PERIOD_NOMINAL_C      : time := 8000.0 ps;  -- 125 MHz
   constant Asic_CLK_PERIOD_NOMINAL_C      : time := 83333.0 ps; -- 12 MHz
   constant CLK_PERIOD_SPREAD_FRACTIONAL_C : real := 0.05;
   constant GATE_DELAY_C : time := 1 ns;

  -- QDBAsic signals
  signal clk     : std_logic;
  signal clk48   : std_logic;
  -- signal asicClk : std_logic;
  signal DaqRx   : std_logic;
  signal DaqTx   : std_logic;
  signal red_led : std_logic;
  signal blu_led : std_logic;
  signal gre_led : std_logic;
  signal IO      : std_logic_vector(3 downto 0);

begin

    -- instantiate the top level of QDBAsic:
    U_QDBAsicTop : entity work.QDBAsicTop
    generic map(
        X_POS_G      => 1,
        Y_POS_G      => 1,
        fake_trg_cnt => 5,
        pulse_time   => 10,
        TXRX_TYPE    => "ENDEAVOR"      -- "DUMMY"/"UART"/"ENDEAVOR"
    )
    port map(
        -- internal clock
        clk     => clk,
        --rst : in STD_LOGIC;
        Tx3     => DaqRx,
        Rx3     => DaqTx,
        -- outputs
        red_led => red_led,
        blu_led => blu_led,
        gre_led => gre_led,
        -- extra IO
        IO      => IO
        -- 'fake'
        -- asicClk    => asicClk
    );

   --
   -- Simulation clocks for signals
   --
   U_QDBAsicClk : entity work.ClkRst
      generic map (
         RST_HOLD_TIME_G   => 1 us -- : time    := 6 us;  -- Hold reset for this long
      )
      port map (
         CLK_PERIOD_G => CLK_PERIOD_NOMINAL_C, -- : time    := 10 ns;
         CLK_DELAY_G  => 1 ns,   -- : time    := 1 ns;  -- Wait this long into simulation before asserting reset
         clkP         => clk48, -- : out sl := '0';
         rst          => open  -- : out sl := '1';
      );

   U_AsicClk : entity work.ClkRst
      generic map (
         RST_HOLD_TIME_G   => 1 us -- : time    := 6 us;  -- Hold reset for this long
      )
      port map (
         CLK_PERIOD_G => Asic_CLK_PERIOD_NOMINAL_C, -- : time    := 10 ns;
         CLK_DELAY_G  => 1 ns,   -- : time    := 1 ns;  -- Wait this long into simulation before asserting reset
         clkP         => clk, -- : out sl := '0';
         rst          => open  -- : out sl := '1';
      );

   ----------------------------
   -- Generate random resets --
   ----------------------------
   stim_proc : process

   begin
      -------------------------------------------------
      -- Initialize the clock phases and frequencies --
      -------------------------------------------------

      --------------------------
      -- Stimulus begins here --
      --------------------------
      wait for 2.0 ns;
        IO <= (others => '0');
        DaqTx   <= '0';

      -- IO trigger and test Tx into array
      wait for 10 ns;
         IO    <= (others => '1');
         DaqTx <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO    <= (others => '0');
         DaqTx <= '0';
      wait for 1000 ns;
         IO    <= (others => '1');
         DaqTx <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO    <= (others => '0');
         DaqTx <= '0';
      wait for 1000 ns;
         IO    <= (others => '1');
         DaqTx <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO    <= (others => '0');
         DaqTx <= '0';

      -- End simulation stimulus by waiting forever
      wait;
   end process;
end Behavioral;
