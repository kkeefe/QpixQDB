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
    --so  : in std_logic;  -- south 6   /  north 4
    --si  : out std_logic;  -- south 4   /  north 2
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
  --signal pllclk       : std_logic              := '0';  
  --signal localCnt     : unsigned (31 downto 0) := (others => '0');
  --signal slv_localCnt : std_logic_vector(31 downto 0);
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

  signal TxPortsArr         : std_logic_vector(3 downto 0);
  signal RxPortsArr         : std_logic_vector(3 downto 0);
  signal inData             : QpixDataFormatType := QpixDataZero_C;
  signal txData             : QpixDataFormatType := QpixDataZero_C;
  signal rxData             : QpixDataFormatType := QpixDataZero_C;
  signal regData            : QpixRegDataType    := QpixRegDataZero_C;
  signal regResp            : QpixRegDataType    := QpixRegDataZero_C;
  signal qpixConf           : QpixConfigType     := QpixConfigDef_C;
  signal qpixreq            : QpixRequestType    := QpixRequestZero_C;
  signal TxReady            : std_logic          := '0';
  --signal fsmState           : std_logic_vector(2 downto 0);

  signal locFifoFull : std_logic := '0';
  signal extFifoFull : std_logic := '0';
  signal routeBusy        : std_logic := '0';
  --signal RxState : std_logic_vector(2 downto 0);

  --signal TxRxDisable : std_logic_vector(3 downto 0) := (others => '0');
  --signal RxError       : std_logic := '0';
  --signal RxBusy        : std_logic := '0';
  --signal RxValidDbg    : std_logic := '0';

   procedure pulseLED(variable flag : in boolean;
                      variable start_pulse : inout std_logic;
                      variable count_pulse : inout integer;
                      signal output : out std_logic) is
      begin
         if flag then
             start_pulse := '1';
             count_pulse := 0;
         end if;
         if start_pulse = '1' then
             count_pulse := count_pulse + 1;
             output <= '1';
             if count_pulse >= pulse_time then
                 count_pulse := 0;
                 start_pulse := '0';
             end if;
         else
            output <= '0';
         end if;
      end procedure pulseLED;


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

    -- LEDs, active LOW (on when value is '0')
    red_led <= not pulse_red; -- not '0' = off, '1' is off
    blu_led <= not pulse_blu;
    gre_led <= not pulse_gre; -- not '0' = off, '1' is off
    
    -- connect Tx to Rx to probe what it thinks it's seeing on scope
    Tx2 <= TxPortsArr(1);
	Tx4 <= TxPortsArr(3);
    Tx1 <= TxPortsArr(3);
	Tx3 <= TxportsArr(2);

    -- clock output to physical
    --si <= clk;
    --so <= pllClk;

     --connect Tx/Rx to the signals
    --Tx3 <= TxPortsArr(2);
    RxPortsArr(0) <= Rx1;
    RxPortsArr(1) <= Rx2;
    RxPortsArr(2) <= Rx3;
    RxPortsArr(3) <= Rx4;

    -- used to buffer readout on timing measurement
    -- si <= clk;
    rst <= qpixreq.AsicReset;

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
    outglobal_o => open
  );


   ----------------------------------------------------------
   --          top level processes to flag for LEDs        --
   ----------------------------------------------------------

    process(clk) is
      variable cb5 : boolean := false;
      variable cg5 : boolean := false;
      variable cr5 : boolean := false;
      variable count : integer range 0 to pulse_time := 0;
      variable pulse_count_red : integer range 0 to pulse_time := 0;
      variable start_pulse_red : std_logic := '0';
      variable pulse_count_gre : integer range 0 to pulse_time := 0;
      variable start_pulse_gre : std_logic := '0';
      variable pulse_count_blu : integer range 0 to pulse_time := 0;
      variable start_pulse_blu : std_logic := '0';
    begin
     if rising_edge(clk) then

        count := count + 1;
        --if count = 19_999_999 then
          --pulse_blu <= not pulse_blu;
          --count := 0;
        --end if;

        -- flash LED conditions for Rx and Tx
        cr5 := rst = '1';
        cg5 := TxPortsArr(1) = '1';
        cb5 := RxPortsArr(1) = '1';

        pulseLED(cb5, start_pulse_blu, pulse_count_blu, pulse_blu);
        pulseLED(cg5, start_pulse_gre, pulse_count_gre, pulse_gre);
        pulseLED(cr5, start_pulse_red, pulse_count_red, pulse_red);


        end if;
    end process;

   ------------TEST MODULES-----------------------
   --U_Rx : entity work.QpixEndeavorRx
      --port map (
          -- Clock and reset
         --clk         => clk,
         --sRst        => '0',

         --scale       => "000",
         --disable     => '0',
         --rxBusy      => open,
         --rxState     => rxState,

          -- Byte signal out
         --rxByte      => open,      -- output
         --rxByteValid => rxByteValid, -- output

         --rxByteAck   => '1',
         --rxError     => open,
         
          -- Error statuses out
         --bitError    => open, -- output
         --lenError    => open, -- output
         --gapError    => open,   -- output

         --Rx          => Rx2 -- input
      --);


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
      rst            => rst,

      EndeavorScale => "000",
      fifoFull      => extFifoFull, -- route fifo full

       -- prototype
      TxRxDisable => "0000", -- external in prototype

      -- phy
      TxPortsArr     => TxPortsArr, -- slv output to physical
      RxPortsArr     => RxPortsArr, -- slv input form physical

      -- route <-> parser
      outData        => txData,  -- record input to parser from route
      inData         => rxData,  -- record output from parser to route
      TxReady        => TxReady, -- sl ready signal to route

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
      rst           => rst,
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
      clkCnt      => clkCnt,
      intrNum     => intrNum,
      extFifoFull => extFifoFull,
      locFifoFull => locFifoFull,
      busy        => routeBusy,
      fsmState    => open
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
      rst            => rst,

      disIfRouteBusy => qpixConf.disIfBusy,
      routeBusy      => routeBusy,
      chanEna        => qpixConf.chanEna,
      clkCnt         => clkCnt,
      fifoFull       => locFifoFull,

      testEna => '0',
      qpixRstPulses => x"000" & IO,
      outData => inData

   );

end Behavioral;
