library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


library work;
use work.QpixPkg.all;

entity QpixAsicFifoDummyTop is
   port (
      --clk            : in std_logic;
      -- rst            : in std_logic;
      
      -- Tx/Rx ports to neighbour ASICs
      Tx3 : out std_logic;
      Rx3 : in  std_logic;
      
      -- other logic
      --rxByteValid_o : out std_logic;
      --txByteValid_o : out std_logic;
      --state_o       : out std_logic;

      -- using spi pins
      --si  : out std_logic;
      --so  : out std_logic;
      --ss  : out std_logic;
      --sck : out std_logic;

      -- LED outputs
      red_led : out STD_LOGIC;
      blu_led : out STD_LOGIC;
      gre_led : out STD_LOGIC
   );
end entity QpixAsicFifoDummyTop;

architecture behav of QpixAsicFifoDummyTop is

  -- pulse signals for LED
  constant pulse_time : integer := 1_999_999;
  signal pulse_red    : std_logic := '0';
  signal pulse_blu    : std_logic := '0';
  signal pulse_gre    : std_logic := '0';

   signal TxByte      : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal RxByte      : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal TxByteValid : std_logic := '0';
   signal TxByteReady : std_logic := '0';
   signal RxByteValid : std_logic := '0';
   signal rxState     : std_logic_vector(2 downto 0) := (others => '0');
   
   signal locFifoEmpty : std_logic := '0';
   signal locFifoFull  : std_logic := '0';

   -- clk / rst
   signal clk : std_logic;
   signal rst : std_logic := '0';
   signal Tx : std_logic := '0';
   signal Rx : std_logic := '0';
   signal cnt : std_logic := '0';
   
   signal bitError : std_logic := '0';
   signal lenError : std_logic := '0';
   signal gapError : std_logic := '0';

   type States is (RX_S, TX_S);
   signal state : States := RX_S;

component HSOSC
GENERIC( CLKHF_DIV :string :="0b00");
PORT(
        CLKHFEN : IN  STD_LOGIC;
        CLKHFPU : IN  STD_LOGIC;
        CLKHF   : OUT STD_LOGIC);
END COMPONENT;

component sdp_ram_ext is
    port(
        wr_clk_i: in std_logic;
        rd_clk_i: in std_logic;
        rst_i: in std_logic;
        wr_clk_en_i: in std_logic;
        rd_en_i: in std_logic;
        rd_clk_en_i: in std_logic;
        wr_en_i: in std_logic;
        wr_data_i: in std_logic_vector(63 downto 0);
        wr_addr_i: in std_logic_vector(7 downto 0);
        rd_addr_i: in std_logic_vector(7 downto 0);
        rd_data_o: out std_logic_vector(63 downto 0)
    );
end component;

begin

  -- normal pin outs
  rst <= '0';
  Tx3 <= Tx;
  Rx <= Rx3;

  -- LEDs, active LOW (on when value is '0')
  -- pulse LEDs
   red_led <= not pulse_red;
   blu_led <= not pulse_blu;
   gre_led <= not pulse_gre;

-- internal oscillator, generate 12 MHz clk
  u_osc : HSOSC
  GENERIC MAP(CLKHF_DIV =>"0b10")
  port map(
      CLKHFEN  => '1',
      CLKHFPU  => '1',
      CLKHF    => clk
  );
  
  -- pulsing
 pulse : process (clk, Rx3, Tx) is
     variable pulse_count_red: integer range 0 to pulse_time := 0;
     variable start_pulse_red: std_logic := '0';
     variable pulse_count_blu: integer range 0 to pulse_time := 0;
     variable start_pulse_blu: std_logic := '0';
     variable pulse_count_gre : integer range 0 to pulse_time := 0;
     variable start_pulse_gre: std_logic := '0';
 begin
     if rising_edge(clk) then

         -- Red
         if lenError = '1' or gapError = '1' or bitError = '1' then
             start_pulse_red := '1';
             pulse_count_red := 0;
         end if;
         if start_pulse_red = '1' then
             pulse_count_red := pulse_count_red + 1;
             pulse_red <= '1';
             if pulse_count_red >= pulse_time then
                 pulse_red       <= '0';
                 pulse_count_red := 0;
                 start_pulse_red := '0';
             end if;
         end if;

         -- Green - Write
         if RxByteValid = '1' and RxByte(63) = '0' then
             start_pulse_gre := '1';
             pulse_count_gre := 0;
         end if;
         if start_pulse_gre = '1' then
             pulse_count_gre := pulse_count_gre + 1;
             pulse_gre <= '1';
             if pulse_count_gre >= pulse_time then
                 pulse_gre       <= '0';
                 pulse_count_gre := 0;
                 start_pulse_gre := '0';
             end if;
         end if;

         -- Blue - Read
         if TxByteValid = '1' then
             start_pulse_blu := '1';
             pulse_count_blu := 0;
         end if;
         if start_pulse_blu = '1' then
             pulse_count_blu := pulse_count_blu + 1;
             pulse_blu <= '1';
             if pulse_count_blu >= pulse_time then
                 pulse_blu       <= '0';
                 pulse_count_blu := 0;
                 start_pulse_blu := '0';
             end if;
         end if;

     end if;
 end process pulse;
   
   QpixTXRx_U : entity work.QpixEndeavorTop
   generic map (
      NUM_BITS_G => G_DATA_BITS 
   )
   port map (
      clk         => clk,
      sRst        => rst,

      txByte      => TxByte,      -- input
      txByteValid => TxByteValid, -- input
      txByteReady => TxByteReady, -- output

      rxFrameErr  => bitError,
      rxBreakErr  => lenError,
      rxGapErr    => gapError,

      rxByte      => RxByte,      -- output
      rxByteValid => RxByteValid, -- output
      rxState     => rxState,      -- output

      Rx          => Rx, -- input physical
      Tx          => Tx  -- output physical
   );

    -- read 64 bit words from Tx/Rx Endeavor - Simple RAM Protocol testing
    -- Echo back different words into the BRAM
    --FIFO_LOC_U : entity work.QDBFifo
    --generic map(
        --DATA_WIDTH => 64,
        --DEPTH      => 8,
        --RAM_TYPE   => "Lattice_ext"
    --)
    --port map(
        --clk   => clk,
        --rst   => rst,
        --din   => RxByte,
        --wen   => RxByteValid,
        --ren   => TxByteValid,
        --dout  => TxByte,
        --empty => locFifoEmpty,
        --full  => locFifoFull
    --);

    -- expose the BRAM directly
    ram_ip_ext : sdp_ram_ext
    port map(
        wr_clk_i=> clk,
        rd_clk_i=> clk,
        rst_i=> '0',
        wr_clk_en_i=> '1',
        rd_clk_en_i=> '1',
        -- write
        wr_addr_i => RxByte(7 downto 0),
        wr_data_i => RxByte,
        wr_en_i   => RxByteValid and not RxByte(63),
        -- read
        rd_addr_i => RxByte(7 downto 0),
        rd_data_o => TxByte,
        rd_en_i   => TxByteValid
    );
	

   process (clk, state, TxByteValid, TxByteReady, TxByte, RxByteValid, RxByte)
   begin
      if rising_edge(clk) then
        TxByteValid <= '0';
        if TxByteReady = '1' then
            if RxByte(63) = '1' and RxBytevalid = '1' then
                TxByteValid <= '1';
            end if;
        end if;
      end if;
   end process;


end behav;
