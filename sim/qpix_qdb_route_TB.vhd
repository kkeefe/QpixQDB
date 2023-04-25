-------------------------------------------------------------------------------
-- Title      : <title string>
-- Project    :
-------------------------------------------------------------------------------
-- File       : qpix_qdb_route_TB.vhd
-- Author     : John Doe  <john@doe.com>
-- Company    :
-- Created    : 2023-04-25
-- Last update: 2023-04-25
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: <cursor>
-------------------------------------------------------------------------------
-- Copyright (c) 2023
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-04-25  1.0      keefe	Created
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Title      : qpix_rotue_TB
-- Project    :
-------------------------------------------------------------------------------
-- File       : qpix_qdb_route_TB.vhd
-- Author     : John Doe  <john@doe.com>
-- Company    :
-- Created    : 2023-04-25
-- Last update: 2023-04-25
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: test the route module
-------------------------------------------------------------------------------
-- Copyright (c) 2023
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2023-04-25  1.0      keefe	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- use IEEE.NUMERIC_STD.ALL;

library work;
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

entity qpxi_qdb_route_TB is
end qpxi_qdb_route_TB;

architecture Behavioral of qpxi_qdb_route_TB is

   constant CLK_PERIOD_NOMINAL_C : time := 33333.0 ps;  -- 12 MHz
   signal clk                    : std_logic;

  signal txData   : QpixDataFormatType := QpixDataZero_C;
  signal rxData   : QpixDataFormatType := QpixDataZero_C;
  signal regData  : QpixRegDataType    := QpixRegDataZero_C;
  signal regResp  : QpixRegDataType    := QpixRegDataZero_C;
  signal qpixConf : QpixConfigType     := QpixConfigDef_C;
  signal qpixreq  : QpixRequestType    := QpixRequestZero_C;
  signal fsmState : std_logic_vector(2 downto 0);

  signal inData       : QpixDataFormatType := QpixDataZero_C;

  -- route output signals
  signal intrNum      : std_logic_vector(15 downto 0);
  signal locFifoFull  : std_logic := '0';
  signal extFifoFull  : std_logic := '0';
  signal locFifoEmpty : std_logic := '0';
  signal extFifoEmpty : std_logic := '0';
  signal routeBusy    : std_logic := '0';

begin
   U_QDBAsicClk : entity work.ClkRst
      generic map (
         RST_HOLD_TIME_G   => 1 us -- : time    := 6 us;  -- Hold reset for this long
      )
      port map (
         CLK_PERIOD_G => CLK_PERIOD_NOMINAL_C, -- : time    := 10 ns;
         CLK_DELAY_G  => 1 ns,   -- : time    := 1 ns;  -- Wait this long into simulation before asserting reset
         clkP         => clk, -- : out sl := '0';
         rst          => open  -- : out sl := '1';
      );

   QpixRoute_U : entity work.QpixRoute
   port map(
      clk           => clk,
      rst           => '0',
       -- reg file connections
      qpixreq       => qpixreq,  -- input register from reg file
      qpixconf      => qpixconf, -- input register from reg file
      -- analog ASIC trigger connections
      inData        => inData,   -- input Data from Process, NOT inData to comm
       -- Qpixcomm connections
      TxReady       => '1',     -- input ready signal from comm
      txData        => txData,  -- output record output to parser
      rxData        => rxData,  -- input record input from parser
       -- debug words:
      --  routeErr      => open,
      --  debug         => debug,
      clkcnt       => x"12345678",
      intrnum      => intrnum,
      extfifofull  => extfifofull,
      locfifofull  => locfifofull,
      extfifoempty => extfifoempty,
      locfifoempty => locfifoempty,
      busy         => routebusy,
      fsmState     => fsmState
        -- state         => route_state,
        -- routeStateInt => open
     );

   stim_proc : process

   begin
      --------------------------
      -- Stimulus begins here --
      --------------------------
      wait for 2.0 ns;
        rxdata.datavalid <= '1';
        rxdata.data <= x"12345678_abcdabcd";

      wait for 50 ns;
        rxdata.datavalid <= '0';

      wait;
   end process;

end Behavioral;
