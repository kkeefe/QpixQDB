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
      pulse_time   : natural := 14_999_999;
      fake_trg_cnt : natural := 19_999_999;
      RAM_TYPE     : string  := "Lattice"; -- 'Lattice' hardcodes BRAM for lattice, or distributed / block
      TXRX_TYPE    : string  := "ENDEAVOR" -- "DUMMY"/"UART"/"ENDEAVOR"
    );
port (
    -- internal clock
    clk : in STD_LOGIC;
--    rst : in STD_LOGIC;

    -- Tx/Rx IO
    --Tx1 : out STD_LOGIC; -- North
    --Rx1 : in STD_LOGIC;
    --Tx2 : out STD_LOGIC; -- East
    --Rx2 : in STD_LOGIC;
    Tx3 : out STD_LOGIC; -- South
    Rx3 : in STD_LOGIC;
    --Tx4 : out STD_LOGIC; -- West
    --Rx4 : in STD_LOGIC;

    -- extra IO, hardcode IO for now
    --IO : in STD_LOGIC_VECTOR(3 downto 0);

    -- optional ss pins -- south Top
     --ss  : in  std_logic;  -- south 8   /  north 6
   --  so  : in std_logic;  -- south 6   /  north 4
   --  si  : out std_logic;  -- south 4   /  north 2
    --sck : in std_logic;   -- south 2   /  north 8

    -- outputs
    red_led : out STD_LOGIC;
    blu_led : out STD_LOGIC;
    gre_led : out STD_LOGIC
    );

end QDBAsicTop;


architecture Behavioral of QDBAsicTop is

  -- timestamp and QDBAsic specifics
  --signal clk          : std_logic;
  signal fast_clk     : std_logic;
  signal pllClk       : std_logic;
  signal fake_trg     : std_logic              := '0';
  signal rst          : std_logic              := '0';
  signal localCnt     : unsigned (31 downto 0) := (others => '0');
  signal slv_localCnt : std_logic_vector(31 downto 0);
  signal pulse_red    : std_logic              := '0';
  signal pulse_blu    : std_logic              := '0';
  signal pulse_gre    : std_logic              := '0';


  -- extra debugs
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
  signal QpixReq            : QpixRequestType    := QpixRequestZero_C;
  signal TxReady            : std_logic          := '0';
  signal fsmState           : std_logic_vector(2 downto 0);

  signal locFifoFull : std_logic := '0';
  signal extFifoFull : std_logic := '0';

  signal TxRxDisable : std_logic_vector(3 downto 0) := (others => '0');
  -- signal RxError       : std_logic := '0';
  signal RxBusy        : std_logic := '0';
  signal RxValidDbg    : std_logic := '0';

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
                 output      <= '0';
                 count_pulse := 0;
                 start_pulse := '0';
             end if;
         end if;
      end procedure pulseLED;


--component HSOSC
--GENERIC( CLKHF_DIV :string :="0b00");
--PORT(
       --CLKHFEN : IN  STD_LOGIC;
       --CLKHFPU : IN  STD_LOGIC;
       --CLKHF   : OUT STD_LOGIC);
--END COMPONENT;


-----------------------------ARCH------------------------------------------
begin

    -- LEDs, active LOW (on when value is '0')
    red_led <= not pulse_red; -- not '0', '1' is off
    blu_led <= not pulse_blu;
    gre_led <= not pulse_gre; -- not '0', '1' is off
    
    -- clock output to physical
	--si <= clk;
    --so <= pllClk;

    -- connect Tx/Rx to the signals
    Tx3 <= TxPortsArr(2);
    RxPortsArr(2) <= Rx3;

  RxPortsArr(0) <= '0';
  RxPortsArr(1) <= '0';
    RxPortsArr(3) <= '0';

    
    -- used to buffer readout on timing measurement
    -- si <= clk;
    rst <= QpixReq.AsicReset;

   ----------------------------------------------------------
   --          top level processes to flag for LEDs        --
   ----------------------------------------------------------

    process(clk) is
      variable cg5 : boolean := false;
      variable cr5 : boolean := false;
      variable count : integer range 0 to 20_000_000 := 0;
     variable pulse_count_red : integer range 0 to pulse_time := 0;
     variable start_pulse_red : std_logic := '0';
     variable pulse_count_gre : integer range 0 to pulse_time := 0;
     variable start_pulse_gre : std_logic := '0';
      variable trg : boolean := false;
      variable clk_cnt : std_logic_vector(31 downto 0) := (others => '0');
	  variable force_reset : boolean := false;
 begin
     if rising_edge(clk) then

    inData.DataValid <= '0';
        count := count + 1;
        if count = 19_999_999 then
          pulse_blu <= not pulse_blu;
          count := 0;
		end if;

        -- flash LED conditions for Rx and Tx
        cg5 := qpixConf.Manroute = '1';
        cr5 := rst = '1';

        pulseLED(cg5, start_pulse_gre, pulse_count_gre, pulse_gre);
        pulseLED(cr5, start_pulse_red, pulse_count_red, pulse_red);


        end if;
    end process;

   ----------------------------------------------------------
   --          optional ICs for the lattice FPGA           --
   ----------------------------------------------------------
    -- use the fast clock to read the input of the data
    -- internal oscillator, generate 50 MHz clk
    --u_osc : HSOSC
    --GENERIC MAP(CLKHF_DIV =>"0b00")
    --port map(
        --CLKHFEN  => '1',
        --CLKHFPU  => '1',
        --CLKHF    => clk
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
      fifoFull      => '0', -- route fifo full

      -- prototype
      TxRxDisable => (others => '0'), -- external in prototype

      -- route <-> parser
      outData        => txData,  -- record input to parser from route
      inData         => rxData,  -- record output from parser to route
      TxReady        => TxReady, -- sl ready signal to route
      -- physical connections
      TxPortsArr     => TxPortsArr, -- slv output to physical
      RxPortsArr     => RxPortsArr, -- slv input form physical
      TxByteValidArr_out => txBytesValid,
      RxByteValidArr_out => rxBytesValid,
      RxFifoEmptyArr_out => open,
      RxFifoFullArr_out  => open,
	  rxBusy => open,
	  rxvaliddbg => open,

      -- reg file connections
      QpixConf       => QpixConf, -- record input
      regData        => regData,  -- output from parser
      regResp        => regResp); -- input from parser
   -----------------------------------------------

   -- Registers file
   -------------------------------------------------
   QpixRegFile_U : entity work.QpixRegFile
   port map(
      clk      => clk,
      rst      => rst,

      -- comm connections
      regData  => regData,  -- input record regData type, from parser
      regResp  => regResp,  -- output record regData type, to parser
      TxReady => open,
      intrNum => open,
      extinterh => open,
      extinters => open,
      clkcntrst => open,
      -- route connections
      QpixConf => QpixConf, -- record qpixConfigType
      QpixReq  => QpixReq   -- record qpixRequestType
      );
   -----------------------------------------------

   -------------------------------------------------
   -- Data routing between ASICs
   -------------------------------------------------
   QpixRoute_U : entity work.QpixRoute
   generic map(
      RAM_TYPE      => RAM_TYPE,
      X_POS_G       => X_POS_G,
      Y_POS_G       => Y_POS_G)
   port map(
      clk           => clk,
      rst           => rst,
      -- reg file connections
      QpixReq       => QpixReq,  -- input register from reg file
      QpixConf      => QpixConf, -- input register from reg file
      -- analog ASIC trigger connections
      inData        => inData,   -- input Data from Process, NOT inData to comm
      -- Qpixcomm connections
      TxReady       => TxReady, -- input ready signal from comm
      txData        => txData,  -- output record output to parser
      rxData        => rxData,  -- input record input from parser
      -- debug words:
      --routeErr      => open,                     
      --debug         => debug,
	  clkCnt 		=> x"0000_0000",
	  intrNum       => open,
	  extFifoFull => open,
	  locFifoFull => open,
	  fsmState    => open
      -- state         => route_state,
      -- routeStateInt => open
	  );
   -----------------------------------------------

end Behavioral;