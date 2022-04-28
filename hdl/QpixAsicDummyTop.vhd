library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


library work;
use work.QpixPkg.all;

entity QpixAsicDummyTop is
   port (
      -- clk            : in std_logic;
      -- rst            : in std_logic;
      
      -- Tx/Rx ports to neighbour ASICs
      Tx3 : out std_logic;
      Rx3 : in  std_logic;

      -- outputs
      red_led : out STD_LOGIC;
      blu_led : out STD_LOGIC;
      gre_led : out STD_LOGIC
   );
end entity QpixAsicDummyTop;

architecture behav of QpixAsicDummyTop is

  -- pulse signals for LED
  constant pulse_time : integer := 1_999_999;
  signal pulse_tx     : std_logic := '0';
  signal pulse_rx     : std_logic := '0';

   signal TxByte      : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal RxByte      : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal RxByteR     : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0');
   signal TxByteValid : std_logic := '0';
   signal TxByteReady : std_logic := '0';
   signal RxByteValid : std_logic := '0';

   -- clk / rst
   signal clk : std_logic;
   signal rst : std_logic := '0';
   signal tx : std_logic := '0';
   signal rx : std_logic := '0';

   type States is (RX_S, TX_S);
   signal state : States := RX_S;

component HSOSC
GENERIC( CLKHF_DIV :string :="0b00");
PORT(
        CLKHFEN : IN  STD_LOGIC;
        CLKHFPU : IN  STD_LOGIC;
        CLKHF   : OUT STD_LOGIC);
END COMPONENT;

begin

  -- LEDs, active LOW (on when value is '0')
  red_led <= not pulse_rx;
  blu_led <= not pulse_tx;
  gre_led <= '1';
  rst <= '0';
  Tx3 <= tx;
  rx <= Rx3;

   -- internal oscillator, generate 50 MHz clk
  u_osc : HSOSC
  GENERIC MAP(CLKHF_DIV =>"0b11")
  port map(
      CLKHFEN  => '1',
      CLKHFPU  => '1',
      CLKHF    => clk
  );

  -- pulsing
 pulse : process (clk, Rx3, Tx) is
     variable pulse_count_rx : integer range 0 to pulse_time := 0;
     variable start_pulse_rx : std_logic := '0';
     variable pulse_count_tx : integer range 0 to pulse_time := 0;
     variable start_pulse_tx : std_logic := '0';
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
         if Tx = '1' then
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

     end if;
 end process pulse;
   
   QpixTXRx_U : entity work.QpixEndeavorTop
   generic map (
      NUM_BITS_G => G_DATA_BITS 
   )
   port map (
      clk         => clk,
      sRst        => rst,

      txByte      => RxByteR, 
      txByteValid => TxByteValid, 
      txByteReady => TxByteReady,

      rxByte      => RxByte,
      rxByteValid => RxByteValid,

      Rx          => Rx,
      Tx          => Tx
   );

   process (clk)
   begin
      if rising_edge(clk) then
      case state is
         when RX_S => 
            TxByteValid <= '0';
            if RxByteValid = '1' then
               RxByteR <= RxByte;
               state <= TX_S;
            end if;
         when TX_S =>
            if TxByteReady = '1' then
               TxByteValid <= '1';
               state <= RX_S;
            end if;
      end case;
         
      end if;
   end process;



end behav;

