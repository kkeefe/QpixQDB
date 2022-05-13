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
   --signal hitMask        : Sl2DArray; -- simulation
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
   signal clk12        : std_logic;
   signal DaqTx        : QpixTxRxPortType;
   signal DaqRx        : QpixTxRxPortType;
   signal evt_fin      : std_logic;
--   signal uartBreakCnt : std_logic_vector(31 downto 0);
--   signal uartFrameCnt : std_logic_vector(31 downto 0);
   signal memAddrRst   : std_logic;
   -- signal memRdAddr    : std_logic_vector(9-1+2 downto 0);
   -- signal memDataOut   : std_logic_vector(31 downto 0);
    signal daqTestWordOut : std_logic_vector(G_DATA_BITS-1 downto 0);
   signal daqTestWordIn  : std_logic_vector(G_DATA_BITS-1 downto 0);

  -- QDBAsic signals
  --signal clk     : std_logic;
  signal asicClk : std_logic;
  signal red_led : std_logic;
  signal blu_led : std_logic;
  signal gre_led : std_logic;
--  type IOports is array (0 to 3) of std_logic_vector(3 downto 0);
--  signal IO : IOports;

  signal C_Tx3 : std_logic;
  signal C_Rx3 : std_logic;

begin

  ----------------------
  -- ASIC Connections --
  ----------------------
  C_Rx3 <= daqTx;
  daqRx <= C_Tx3;


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
        hitMask        => open,
        timestamp      => timestamp,
        chanMask       => chanMask,
        trg            => trg, -- trg
        -- asic outputs to QpixDaqCtrl
        asicReq        => asicReq,
        asicOpWrite    => asicOpWrite,
        asicData       => asicData,
        asicAddr       => asicAddr,
        -- memory fifo within QpixDaqCtrl
        memRdReq       => memRdReq,
        memRdAck       => memRdAck,
        memData        => memData,
        memAddr        => memAddr,
        
        daqTestWordOut => daqTestWordOut,
        daqTestWordIn  => daqTestWordIn
      );

    U_QpixDaqCtrl : entity work.QpixDaqCtrlDummy
      port map(
        clk          => clk12,
        rst          => rst,
        daqTx        => daqTx,
        daqRx        => daqRx,
        -- trg in and status signals
        trg          => trg,
 
        sndWord     => daqTestWordOut,
        recWord     => daqTestWordIn,
        busy        => status(0)
      );
      memAddrRst <= trg or asicReq;

    -- ASIC-C, "main" ASIC that speaks with DaqNode
    U_QDBAsicC : entity work.QpixAsicDummyTop
    port map(
        -- internal clock
        clk => clk12,

        Tx3 => C_Tx3,
        Rx3 => C_Rx3,

        -- outputs
        red_led => red_led,
        blu_led => blu_led,
        gre_led => gre_led
    );

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
         clkP         => clk12, -- : out sl := '0';
         rst          => open  -- : out sl := '1';
      );

   ----------------------------
   -- Generate random resets --
   ----------------------------
   stim_proc : process

   begin
      -- TODO
      -------------------------------------------------
      -- Initialize the clock phases and frequencies --
      -------------------------------------------------

      --------------------------
      -- Stimulus begins here --
      --------------------------
      wait for 2.0 ns;
        status   <= x"beefcafe";
        addr     <= (others => '0');
        wdata    <= 0x"1234abcd";
        rst <= '0';
        -- turn off reception from un-connected directions
        wen <= '0';
        req <= '0';


      wait for 10 us; -- (sets C manual routing, successfully)
        req   <= '1';
        wdata <= x"0000000" & b"0000";    -- set ManRoute '1' and DirMask "DirDown" from QPixPkg.vhd 
        wen <= '1';                       -- opWrite
        addr  <= x"000" & x"c" & x"080c"; -- C for remote, 100 for dest & X/Y, c=3<<2 for dir mask
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        req <= '0';

    -- write the top high word
      wait for 20 us; -- (sets C manual routing, successfully)
        req   <= '1';
        wdata <= x"ffff_ffff"; 
        wen <= '1';                       -- opWrite
        addr  <= x"0000_002c";
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        req <= '0';

    -- verified sends trigger
    -- send the trigger to 0x0a << 2 = 0x28
      wait for 100 us; -- (sets C manual routing, successfully)
        req   <= '1';
        wdata <= x"aaaa_aaaf"; 
        wen <= '1';                       -- opWrite
        addr  <= x"0000_0028";
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        req <= '0';

    -- repeat send the trigger 1 ms later..
    -- send the trigger to 0x0a << 2 = 0x28
      wait for 1 ms; -- (sets C manual routing, successfully)
        req   <= '1';
        wdata <= x"0000_0001"; 
        wen <= '1';                       -- opWrite
        addr  <= x"0000_0028";
      wait for Asic_CLK_PERIOD_NOMINAL_C * 2;
        req <= '0';



     
      -- End simulation stimulus by waiting forever
      wait;
   end process;
end Behavioral;
