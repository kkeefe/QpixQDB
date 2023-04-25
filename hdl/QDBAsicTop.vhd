library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- qpix things
library work;
use work.QpixPkg.all;

-- std rtl things
use work.stdrtlpkg.all;

-- ice things
--library ice;
--use ice.all;

entity QDBAsicTop is
   generic (
      X_POS_G      : natural := 0;
      Y_POS_G      : natural := 0;
      pulse_time   : natural := 9_999_999;
      RAM_TYPE     : string  := "Lattice"; -- 'Lattice' hardcodes BRAM for lattice, or distributed / block
      TXRX_TYPE    : string  := "ENDEAVOR" -- "DUMMY"/"UART"/"ENDEAVOR"
    );
port (
    -- internal clock
    pllclk : in STD_LOGIC;
    --rst : in STD_LOGIC;

    -- Tx/Rx IO
    Tx1 : out STD_LOGIC; -- North
    Rx1 : in STD_LOGIC;
    Tx2 : out STD_LOGIC; -- East
    Rx2 : in STD_LOGIC;
    Tx3 : out STD_LOGIC; -- South
    Rx3 : in STD_LOGIC;
    Tx4 : out STD_LOGIC; -- West
    Rx4 : in STD_LOGIC;

    -- extra IO, hardcode IO for now
    IO : in STD_LOGIC_VECTOR(3 downto 0);

    -- optional ss pins -- south Top
    --ss  : in  std_logic;  -- south 8   /  north 6
    so  : out std_logic;  -- south 6   /  north 4
    si  : out std_logic;  -- south 4   /  north 2
    --sck : in std_logic;   -- south 2   /  north 8

    -- outputs
    red_led : out STD_LOGIC;
    blu_led : out STD_LOGIC;
    gre_led : out STD_LOGIC
    );

end QDBAsicTop;


architecture Behavioral of QDBAsicTop is

  -- timestamp and QDBAsic specifics
  signal clk          : std_logic;
  signal rst          : std_logic              := '0';
  signal routeRst          : std_logic              := '0';
  --signal pllclk       : std_logic              := '0';  

  signal pulse_red    : std_logic              := '0';
  signal pulse_blu    : std_logic              := '0';
  signal pulse_gre    : std_logic              := '0';

  -- extra debugs
  --signal rxByteValid : std_logic := '0';
  signal rxBytesValid : std_logic_vector(3 downto 0);
  signal txBytesValid : std_logic_vector(3 downto 0);

  -- extra signals to QpixRegFile.vhd
  --signal  clkCntRst : std_logic;
  --signal  extInterS : std_logic;
  --signal  extInterH : std_logic;
  signal  intrNum   : std_logic_vector(15 downto 0);
  signal  clkCnt    : std_logic_vector(31 downto 0);

  signal TxPortsArr   : std_logic_vector(3 downto 0);
  signal RxPortsArr   : std_logic_vector(3 downto 0);
  signal inData       : QpixDataFormatType := QpixDataZero_C;
  signal txData       : QpixDataFormatType := QpixDataZero_C;
  signal rxData       : QpixDataFormatType := QpixDataZero_C;
  signal regData      : QpixRegDataType    := QpixRegDataZero_C;
  signal regResp      : QpixRegDataType    := QpixRegDataZero_C;
  signal qpixConf     : QpixConfigType     := QpixConfigDef_C;
  signal qpixreq      : QpixRequestType    := QpixRequestZero_C;
  signal TxReady      : std_logic          := '0';
  signal TxReadyMaskV : std_logic_vector(3 downto 0);
  signal fsmState           : std_logic_vector(2 downto 0);

  signal locFifoFull  : std_logic := '0';
  signal extFifoFull  : std_logic := '0';
  signal locFifoEmpty : std_logic := '0';
  signal extFifoEmpty : std_logic := '0';
  signal routeBusy    : std_logic := '0';
  --signal RxState : std_logic_vector(2 downto 0);

  --signal TxRxDisable : std_logic_vector(3 downto 0) := (others => '0');
  --signal RxError       : std_logic := '0';
  --signal RxBusy        : std_logic := '0';
  --signal RxValidDbg    : std_logic := '0';

--component HSOSC
--GENERIC( CLKHF_DIV :string :="0b00");
--PORT(
       --CLKHFEN : IN  STD_LOGIC;
       --CLKHFPU : IN  STD_LOGIC;
       --CLKHF   : OUT STD_LOGIC);
--END COMPONENT;

component qdb_pll is
    port(
        ref_clk_i   : in  std_logic;
        rst_n_i     : in  std_logic;
        outcore_o   : out std_logic;
        outglobal_o : out std_logic
    );
end component;

-----------------------------ARCH------------------------------------------
begin
    
    -- connect Tx to Rx to probe what it thinks it's seeing on scope
    Tx1 <= TxPortsArr(0);
    --Rx1 <= TxPortsArr(3);
    Tx2 <= TxPortsArr(1);
    Tx3 <= TxportsArr(2);
    Tx4 <= TxPortsArr(3);

    -- scope probes
    so <= TxPortsArr(1); -- pin 4 A | pin 4 B
    si <= TxPortsArr(3); -- pin 6 A | pin 2 B

    --connect Tx/Rx to the signals
    --Tx3 <= TxPortsArr(2);
    RxPortsArr(0) <= Rx1;
    RxPortsArr(1) <= Rx2;
    RxPortsArr(2) <= Rx3;
    RxPortsArr(3) <= Rx4;

    -- used to buffer readout on timing measurement
    rst      <= qpixreq.AsicReset;
    routeRst <= qpixreq.ResetState;

   ----------------------------------------------------------
   --          optional ICs for the lattice FPGA           --
   ----------------------------------------------------------
    -- use the fast clock to read the input of the data
    -- internal oscillator, generate 50 MHz clk
    --u_osc : HSOSC
    --GENERIC MAP(CLKHF_DIV =>"0b10") -- b'10 is 12 MHz
    --port map(
        --CLKHFEN  => '1',
        --CLKHFPU  => '1',
        --CLKHF    => pllclk
    --);

  -- pll to buff up clock from 12 MHz to 30 MHz
  u_pll : qdb_pll port map(
    ref_clk_i   =>  pllclk,
    rst_n_i     =>  '1', -- active low
    outcore_o   =>  clk,
    outglobal_o =>  open
  );


   ----------------------------------------------------------
   --          top level processes to flag for LEDs        --
   ----------------------------------------------------------
   QDBLed_U : entity work.QDBLed
   generic map(
      pulse_time     => pulse_time
      )
   port map(
      clk            => clk,
      rst            => rst,

      -- conditional inputs
      --cond_red_led => (not regdata.dest = '1') and regdata.valid = '1', -- received a broadcast
      -- received a specific regreq
      -- cond_gre_led => regdata.ydest = qpixconf.ypos and regdata.xdest = qpixconf.xpos and regdata.valid = '1' and regdata.dest = '1',
      cond_gre_led => extFifoEmpty = '0',
      cond_red_led => rxData.datavalid = '1', -- reading new input data
      cond_blu_led => txData.datavalid = '1', -- busy is always read

      -- outputs
      red_led => pulse_red,
      gre_led => pulse_gre,
      blu_led => pulse_blu
      );
    -- LEDs, active LOW (on when value is '0')
    red_led <= not pulse_red; -- not '0' = off, '1' is off
    blu_led <= not pulse_blu;
    gre_led <= not pulse_gre; -- not '0' = off, '1' is off


   ------------MODULES----------------------------
   -----------------------------------------------
   -- Q-Pix data tranceiver
   -- data parsing / physical layer
   -----------------------------------------------
   QpixComm_U : entity work.QpixComm
   generic map(
      RAM_TYPE      => RAM_TYPE,
      TXRX_TYPE     => TXRX_TYPE
      )
   port map(
      clk            => clk,
      rst            => routeRst,

      EndeavorScale => "000",
      fifoFull      => extFifoFull, -- route fifo full

       -- prototype
      TxRxDisable => "0000", -- external in prototype

      -- phy
      TxPortsArr     => TxPortsArr, -- slv output to physical
      RxPortsArr     => RxPortsArr, -- slv input form physical

      -- route <-> parser
      outData      => txData,           -- record input to parser from route
      inData       => rxData,           -- record output from parser to route
      TxReady      => TxReady,          -- sl ready signal to route
      TxReadyMaskV => TxReadyMaskV,     -- sl ready signal to route

      -- debug
      TxByteValidArr_out => open,
      RxByteValidArr_out => rxBytesValid,
      RxFifoEmptyArr_out => txBytesValid,
      RxFifoFullArr_out  => open,
      RxBusy             => open,
      RxError            => open,
      Rxvaliddbg         => open,
      RxState            => open,

      -- reg file connections
      qpixconf       => qpixconf, -- record input
      regData        => regData,  -- output from parser
      regResp        => regResp); -- input from parser

   -------------------------------------------
   --Registers file
   ---------------------------------------------
   QpixRegFile_U : entity work.QpixRegFile
   port map(
      clk      => clk,
      rst      => rst,

      clkCnt   => clkCnt,
      -- comm connections
      regData  => regData,  -- input record regData type, from parser
      regResp  => regResp,  -- output record regData type, to parser
      TxReady   => TxReady,
      intrNum   => intrNum,
      extinterh => '0',
      extinters => '0',
      clkcntrst => '0',

      -- route connections
      qpixconf => qpixconf, -- record qpixConfigType
      qpixreq  => qpixreq   -- record qpixRequestType
      );
   -------------------------------------------

   ---------------------------------------------
   --Data routing between ASICs
   ---------------------------------------------
   QpixRoute_U : entity work.QpixRoute
   generic map(
      RAM_TYPE      => RAM_TYPE,
      X_POS_G       => X_POS_G,
      Y_POS_G       => Y_POS_G)
   port map(
      clk           => clk,
      rst           => routeRst,
       -- reg file connections
      qpixreq       => qpixreq,  -- input register from reg file
      qpixconf      => qpixconf, -- input register from reg file
      -- analog ASIC trigger connections
      inData        => inData,   -- input Data from Process, NOT inData to comm
       -- Qpixcomm connections
      TxReady       => TxReady, -- input ready signal from comm
      txData        => txData,  -- output record output to parser
      rxData        => rxData,  -- input record input from parser
       -- debug words:
      --  routeErr      => open,
      --  debug         => debug,
      clkcnt       => clkcnt,
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
   -----------------------------------------------

   -------------------------------------------------
   -- Process ASIC internal data with defined format
   ---------------------------------------------------
   QpixDataProc_U : entity work.QpixDataProc
   port map(
      clk            => clk,
      rst            => routeRst,

      disIfRouteBusy => qpixConf.disIfBusy,
      routeBusy      => routeBusy,
      chanEna        => qpixConf.chanEna,
      clkCnt         => clkCnt,
      fifoFull       => locFifoFull,

      testEna       => '0',
      qpixRstPulses => x"000" & IO,
      outData       => inData
   );

end Behavioral;
