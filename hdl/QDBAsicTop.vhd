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
      pulse_time   : natural :=  0_999_999;
      fake_trg_cnt : natural := 36_999_999;
      RAM_TYPE     : string  := "Lattice"; -- lattice hardcodes BRAM for lattice, or distributed / block
      TXRX_TYPE    : string  := "ENDEAVOR" -- "DUMMY"/"UART"/"ENDEAVOR"
    );
port (
    -- internal clock
    clk : in STD_LOGIC;
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
    --IO : in STD_LOGIC_VECTOR(3 downto 0);

    -- optional ss pins -- south Top
    --ss  : in std_logic; -- south 8   /  north 6
    --so  : in std_logic; -- south 6   /  north 4
    --si  : in std_logic; -- south 4   /  north 2
    --sck : in std_logic; -- south 2   /  north 8

    -- outputs
    red_led : out STD_LOGIC;
    blu_led : out STD_LOGIC;
    gre_led : out STD_LOGIC
    );

end QDBAsicTop;


architecture Behavioral of QDBAsicTop is

  -- timestamp and QDBAsic specifics
  signal fake_trg     : std_logic := '0';
  signal count        : integer range 0 to 50000000;
  signal rst          : std_logic := '0';
--  signal clk          : std_logic;
  signal localCnt     : unsigned (31 downto 0) := (others => '0');
  signal slv_localCnt : std_logic_vector(31 downto 0);
  signal pulse_tx     : std_logic := '0';
  signal pulse_rx     : std_logic := '0';
  signal pulse_trg    : std_logic := '0';
  signal spi_input    : std_logic := '0';

  -- QpixAsicTop copied signals
  signal inData       : QpixDataFormatType := QpixDataZero_C;
  signal txData       : QpixDataFormatType := QpixDataZero_C;
  signal rxData       : QpixDataFormatType := QpixDataZero_C;
  signal regData      : QpixRegDataType    := QpixRegDataZero_C;
  signal regResp      : QpixRegDataType    := QpixRegDataZero_C;
  signal qpixConf     : QpixConfigType     := QpixConfigDef_C;
  signal qpixReq      : QpixRequestType    := QpixRequestZero_C;
  signal TxReady      : std_logic          := '0';
  -- signal localDataEna : std_logic := '0';
  -- signal inPorts      :  QpixInPortsType;
  signal TxPortsArr   :  std_logic_vector(3 downto 0);
  signal RxPortsArr   :  std_logic_vector(3 downto 0);

  -- simulation monitor
  -- signal spulse_count : integer range 0 to pulse_time := 0;
  -- signal sstart_pulse : std_logic;

--component HSOSC
--GENERIC( CLKHF_DIV :string :="0b00");
--PORT(
--        CLKHFEN : IN  STD_LOGIC;
--        CLKHFPU : IN  STD_LOGIC;
--        CLKHF   : OUT STD_LOGIC);
--END COMPONENT;

begin

    -- LEDs, active LOW (on when value is '0')
    red_led <= not pulse_rx;
    blu_led <= not pulse_tx;
    gre_led <= not pulse_trg;
    --spi_input <= si;
    rst <= '0';

    -- internal oscillator, generate 50 MHz clk
--  u_osc : HSOSC
--  GENERIC MAP(CLKHF_DIV =>"0b11")
--  port map(
--      CLKHFEN  => '1',
--      CLKHFPU  => '1',
--      CLKHF    => clk
--  );

    -- connect Tx/Rx to the signals
    Tx1 <= TxPortsArr(0);
    RxPortsArr(0) <= Rx1;
    Tx2 <= TxPortsArr(1);
    RxPortsArr(1) <= Rx2;
    Tx3 <= TxPortsArr(2);
    RxPortsArr(2) <= Rx3;
    --Tx4 <= TxPortsArr(3);
    --RxPortsArr(3) <= Rx4;

--  -- create a 1 second pulse width when either Tx or Rx goes high
 pulse : process (clk, Rx3, pulse_rx, TxPortsArr(2), fake_trg) is
     variable pulse_count_rx : integer range 0 to pulse_time := 0;
     variable start_pulse_rx : std_logic := '0';
     variable pulse_count_tx : integer range 0 to pulse_time := 0;
     variable start_pulse_tx : std_logic := '0';
     variable pulse_count_trg : integer range 0 to pulse_time := 0;
     variable start_pulse_trg : std_logic := '0';
 begin
     if rising_edge(clk) then

         -- pulse the Rx, Red
         if Rx3 = '1' then
             start_pulse_rx := '1';
             pulse_count_rx := 0;
         end if;
         if start_pulse_rx = '1' then
             pulse_count_rx := pulse_count_rx + 1;
             pulse_rx <= '1';
             if pulse_count_rx >= pulse_time then
                 pulse_rx       <= '0';
                 pulse_count_rx := 0;
                 start_pulse_rx := '0';
             end if;
         end if;

         -- pulse the Tx, Blue
         if TxPortsArr(2) = '1' then
             start_pulse_tx := '1';
             pulse_count_tx := 0;
         end if;
         if start_pulse_tx = '1' then
             pulse_count_tx := pulse_count_tx + 1;
             pulse_tx <= '1';
             if pulse_count_tx >= pulse_time then
                 pulse_tx       <= '0';
                 pulse_count_tx := 0;
                 start_pulse_tx := '0';
             end if;
         end if;

         if fake_trg = '1' then
             start_pulse_trg := '1';
             pulse_count_trg := 0;
         end if;
         if start_pulse_trg = '1' then
             pulse_count_trg := pulse_count_trg + 1;
             pulse_trg <= '1';
             if pulse_count_trg >= pulse_time then
                 pulse_trg <= '0';
                 pulse_count_trg := 0;
                 start_pulse_trg := '0';
             end if;
         end if;

         --simulation only
        --spulse_count <= pulse_count_rx;
        --sstart_pulse <= start_pulse_rx;

     end if;
 end process pulse;

   -------------------------------------------------
   -- Process ASIC internal data with defined format
   -------------------------------------------------
   --QpixDataProc_U : entity work.QpixDataProc
   --generic map(
      --X_POS_G => X_POS_G,
      --Y_POS_G => Y_POS_G)
   --port map(
      --clk     => clk,
      --rst     => rst,
      --ena     => localDataEna,
      --testEna => '0',
      --inPorts => inPorts,
      --outData => inData);

    -- connect external IO to QpixDataProc
    slv_localCnt <= std_logic_vector(localCnt);
    process (clk)
      begin
         if rising_edge (clk) then
            if fake_trg = '1' then
               inData.DataValid <= '1';
               inData.TimeStamp <= slv_localCnt;

            else
               inData.DataValid <= '0';
               inData.TimeStamp <= (others => '0');
              end if;
            end if;
         end process;
    inData.ChanMask <=  (others => '1');
	inData.xpos     <= toslv(X_POS_G, 4);
    inData.ypos     <= toslv(Y_POS_G, 4);
    inData.data     <= (others => '1');
    inData.wordtype <= (others => '0');
    inData.dirMask  <= DirDown;

    counter: process (clk) is
    begin
        if clk'event and clk = '1' then     -- rising clock edge
            count <= count + 1;
            localCnt <= localCnt + 1;
          if count >= fake_trg_cnt then
            fake_trg <= '1';
            count <= 0;
          else
            fake_trg <= '0';
          end if;
        end if;
    end process counter;
   ---------------------------------------------

   -- Q-Pix data tranceiver
   -- data parsing / physical layer
   -------------------------------------------------
   QpixComm_U : entity work.QpixComm
   generic map(
      RAM_TYPE      => RAM_TYPE,
      TXRX_TYPE     => TXRX_TYPE,
      X_POS_G       => X_POS_G,
      Y_POS_G       => Y_POS_G)
   port map(
      clk            => clk,
      rst            => rst,
      -- route <-> parser
      outData_i      => txData,  -- record input to parser from route
      inData         => rxData,  -- record output from parser to route
      TxReady        => TxReady, -- sl ready signal to route
      -- physical connections
      TxPortsArr     => TxPortsArr, -- slv output to physical
      RxPortsArr     => RxPortsArr, -- slv input form physical
      -- unused / changed
      QpixConf       => QpixConf, -- record input
--    QpixReq        => open,
      -- reg file connections
      regData        => regData,  -- output from parser
      regResp        => regResp); -- input from parser
   -----------------------------------------------

   -- Registers file
   -------------------------------------------------
   QpixRegFile_U : entity work.QpixRegFile
   generic map(
      X_POS_G       => X_POS_G,
      Y_POS_G       => Y_POS_G)
   port map(
      clk      => clk,
      rst      => rst,
      -- comm connections
      regData  => regData,  -- record regData type
      regResp  => regResp,  -- record regData type
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
      qpixReq       => QpixReq,  -- input register from reg file
      qpixConf      => QpixConf, -- input register from reg file
      -- analog ASIC trigger connections
      inData        => inData,   -- Data from Process, NOT inData to comm
      localDataEna  => open,
      -- comm connections
      txReady       => TxReady, -- ready signal from comm
      txData        => txData,  -- record output to parser
      rxData        => rxData,  -- record input from parser
      -- unused
      routeErr      => open,                     
      debug         => open,
      routeStateInt => open);
   -----------------------------------------------

end Behavioral;
