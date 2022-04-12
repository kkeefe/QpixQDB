----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/05/2022 05:37:43 PM
-- Design Name: 
-- Module Name: qpix_qdb_sim_TB - Behavioral
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

entity qpix_qdb_sim_TB is
end qpix_qdb_sim_TB;

architecture Behavioral of qpix_qdb_sim_TB is

  -- constants for clocks and simulation
   constant CLK_PERIOD_NOMINAL_C           : time := 20833.0 ps; -- 48 MHz
   constant Zynq_CLK_PERIOD_NOMINAL_C      : time := 8000.0 ps;  -- 125 MHz
   constant Asic_CLK_PERIOD_NOMINAL_C      : time := 83333.0 ps; -- 12 MHz
   constant CLK_PERIOD_SPREAD_FRACTIONAL_C : real := 0.05;
   constant GATE_DELAY_C : time := 1 ns;
   constant MEM_DEPTH : natural := 12;

   -- ZyboRegisters
   signal clk48          : std_logic;
   signal rst            : std_logic;
   signal addr           : std_logic_vector(31 downto 0);
   signal rdata          : std_logic_vector(31 downto 0);
   signal wdata          : std_logic_vector(31 downto 0);
   signal req            : std_logic;
   signal wen            : std_logic;
   signal ack            : std_logic;
   signal asic_mask      : std_logic_vector(15 downto 0) := (others => '1');
   signal evtSize        : std_logic_vector(31 downto 0);
   signal status         : std_logic_vector(31 downto 0);
   signal daqFrameErrCnt : std_logic_vector(31 downto 0);
   signal daqBreakErrCnt : std_logic_vector(31 downto 0);
   signal extFifoMax     : Slv4b2DArray;
   signal trgTime        : std_logic_vector(31 downto 0);
   -- signal hitMask        : Sl2DArray(0 to X_NUM_G-1, 0 to Y_NUM_G-1);
   signal hitMask        : Sl2DArray; -- simulation
   signal timestamp      : std_logic_vector(31 downto 0);
   signal chanMask       : std_logic_vector(G_N_ANALOG_CHAN-1 downto 0) := (others => '1');
   signal trg            : std_logic;
   signal asicAddr       : std_logic_vector(31 downto 0);
   signal asicOpWrite    : std_logic;
   signal asicData       : std_logic_vector(15 downto 0);
   signal asicReq        : std_logic;
   signal memRdReq       : std_logic;
   signal memRdAck       : std_logic;
   signal memData        : std_logic_vector(31 downto 0);
   signal memAddr        : std_logic_vector(G_QPIX_PROTO_MEM_DEPTH-1+2 downto 0);

   -- ZybDaq Node
   signal clk12          : std_logic;
   signal daqTx        : QpixTxRxPortType;
   signal daqRx        : QpixTxRxPortType;
   signal evt_fin      : std_logic;
   signal uartBreakCnt : std_logic_vector(31 downto 0);
   signal uartFrameCnt : std_logic_vector(31 downto 0);
   signal memAddrRst   : std_logic;
   -- signal memRdAddr    : std_logic_vector(9-1+2 downto 0);
   -- signal memDataOut   : std_logic_vector(31 downto 0);

  -- QDBAsic signals
  --signal clk     : std_logic;
  signal asicClk : std_logic;
  signal red_led : std_logic;
  signal blu_led : std_logic;
  signal gre_led : std_logic;
  signal IO      : std_logic_vector(3 downto 0);

begin

    -- instantiate a portion of the top level here
    U_QpixProtoRegMap : entity work.QpixProtoRegMap
      generic map(
        X_NUM_G => 1,
        Y_NUM_G => 1)
      port map(
        clk            => clk12,
        rst            => rst,
        -- axi protocol information
        addr           => addr,
        rdata          => rdata,
        wdata          => wdata,
        req            => req,
        wen            => wen,
        ack            => ack,
        -- register information
        asic_mask      => asic_mask,
        evtSize        => evtSize,
        status         => status,
        daqFrameErrCnt => daqFrameErrCnt,
        daqBreakErrCnt => daqBreakErrCnt,
        extFifoMax     => extFifoMax,
        trgTime        => trgTime,
        hitMask        => hitMask,
        timestamp      => timestamp,
        chanMask       => chanMask,
        trg            => open, -- trg
        -- asic outputs to QpixDaqCtrl
        asicReq        => asicReq,
        asicOpWrite    => asicOpWrite,
        asicData       => asicData,
        asicAddr       => asicAddr,
        -- memory fifo within QpixDaqCtrl
        memRdReq       => memRdReq,
        memRdAck       => memRdAck,
        memData        => memData,
        memAddr        => memAddr
      );

    U_QpixDaqCtrl : entity work.QpixDaqCtrl
      generic map(
        MEM_DEPTH => MEM_DEPTH,
        TXRX_TYPE => "ENDEAVOR" -- "DUMMY"/"UART"/"ENDEAVOR"
      )
      port map(
        clk          => clk12,
        rst          => rst,
        daqTx        => daqTx,
        daqRx        => daqRx,
        -- trg in and status signals
        trg          => trg,
        trgTime      => trgTime,
        evt_fin      => evt_fin,
        uartBreakCnt => uartBreakCnt,
        uartFrameCnt => uartFrameCnt,
        -- asic inputs from QpixProtoRegMap
        asicReq      => asicReq,
        asicOpWrite  => asicOpWrite,
        asicData     => asicData,
        asicAddr     => asicAddr,
        asic_mask    => asic_mask,
        -- memory data stored in fifo
        memRdReq     => memRdReq,
        memRdAck     => memRdAck,
        memDataOut   => memData,
        memEvtSize   => evtSize,
        memAddrRst   => memAddrRst,
        memRdAddr    => memAddr,
        memFullErr   => open
      );
      memAddrRst <= trg or asicReq;

    -- instantiate the top level of QDBAsic:
    U_QDBAsicTop : entity work.QDBAsicTop
    generic map(
        X_POS_G   => 1,
        Y_POS_G   => 1,
        TXRX_TYPE => "ENDEAVOR" -- "DUMMY"/"UART"/"ENDEAVOR"
    )
    port map(
        -- internal clock
        clk => clk12,
        --rst : in STD_LOGIC;
        Tx3 => DaqRx,
        Rx3 => DaqTx,
        -- outputs
        red_led => red_led,
        blu_led => blu_led,
        gre_led => gre_led,
        -- extra IO
        IO => IO
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

--   U_QDBDaqClk : entity work.ClkRst
--      generic map (
--         RST_HOLD_TIME_G   => 1 us -- : time    := 6 us;  -- Hold reset for this long
--      )
--      port map (
--         CLK_PERIOD_G => Zynq_CLK_PERIOD_NOMINAL_C, -- : time    := 10 ns;
--         CLK_DELAY_G  => 1 ns,   -- : time    := 1 ns;  -- Wait this long into simulation before asserting reset
--         clkP         => sysClk, -- : out sl := '0';
--         rst          => open  -- : out sl := '1';
--      );

   U_AsicClk : entity work.ClkRst
      generic map (
         RST_HOLD_TIME_G   => 1 us -- : time    := 6 us;  -- Hold reset for this long
      )
      port map (
         CLK_PERIOD_G => Asic_CLK_PERIOD_NOMINAL_C, -- : time    := 10 ns;
         CLK_DELAY_G  => 1 ns,   -- : time    := 1 ns;  -- Wait this long into simulation before asserting reset
         clkP         => clk12, -- : out sl := '0';
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
        status   <= x"beefcafe";
        addr     <= x"000" & x"c" & x"0000"; -- unused & asic reg-request & asicAddr
        wdata    <= 0x"1234abcd";
        IO <= (others => '0');
        trg <= '0';
        rst <= '0';
      
      -- initial request
        wen <= '1';
        req <= '0';
      wait for 100 ns;      
        req <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        req <= '0';
        wen <= '0';

      -- IO triggers - 1,2,3
      wait for 10 us;      
         IO <= (others => '1');
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO <= (others => '0');
      wait for 5 us;      
         IO <= (others => '1');
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO <= (others => '0');
      wait for 5 us;      
         IO <= (others => '1');
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
         IO <= (others => '0');

      -- local fifo interrogations
      wait for 500 us;
        req   <= '1';
        wdata <= x"00000001";             -- set interrogation
        wen <= '0';                       -- opRead
        addr  <= x"000" & x"c" & x"0124"; -- C for remote, 012 for X/Y, 1 for interrogation
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        trg <= '0';
        req <= '0';

      -- Read EvtSize -> Should get 8 since that's how many events are in DaqCtrl BRAM
      wait for 2 ms;
        addr  <= x"00000010"; -- read the event size
        req   <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2; 
        req <= '0';

      -- try to read in from the event memory 
      wait for 50 us;
      ----------   unused & evtMmem &  addr  & mux  & unused
          addr  <= x"000" &   x"4"  & x"001" & "00" & "00";
          req   <= '1';
      wait for Asic_CLK_PERIOD_NOMINAL_C * 10;              
          req <= '0';
     
      -- End simulation stimulus by waiting forever
      wait;
   end process;
end Behavioral;