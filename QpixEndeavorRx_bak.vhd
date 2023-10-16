----------------------------------------------------------------------------------
--
--
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
-- use IEEE.math_real."ceil";
-- use IEEE.math_real."log2";

entity qpixendeavorrx is
  generic (
    num_bits_g   : natural := 64;
    gate_delay_g : time    := 1 ns;
    n_zer_min_g  : natural := 4;
    n_zer_max_g  : natural := 12;
    n_one_min_g  : natural := 16;
    n_one_max_g  : natural := 32;
    n_gap_min_g  : natural := 8;
    n_gap_max_g  : natural := 32;
    n_fin_min_g  : natural := 32
  );
  port (
    -- Clock and reset
    clk     : in    std_logic;
    srst    : in    std_logic;
    scale   : in    std_logic_vector(2 downto 0);
    disable : in    std_logic;

    biterror : out   std_logic;
    gaperror : out   std_logic;
    lenerror : out   std_logic;
    rxerror  : out   std_logic;
    rxbusy   : out   std_logic;

    -- Byte data received
    rxbyte      : out   std_logic_vector(num_bits_g - 1 downto 0);
    rxbytevalid : out   std_logic;
    rxbyteack   : in    std_logic;
    rx          : in    std_logic
  );
end entity qpixendeavorrx;

architecture behavioral of qpixendeavorrx is

  type statetype is (idle_s, data_s, bit_s, gap_s,  finish_s, wait_finish_s);

  type regtype is record
    state     : statetype;
    byte      : std_logic_vector(num_bits_g - 1 downto 0);
    dataOut   : std_logic_vector(num_bits_g - 1 downto 0);
    byteValid : std_logic;
    lowCnt    : unsigned(7 downto 0);
    highCnt   : unsigned(7 downto 0);
    byteCount : unsigned(7 downto 0);
    waitCnt   : unsigned(7 downto 0);
    bitError  : std_logic;
    gapError  : std_logic;
    lenError  : std_logic;
    disable   : std_logic;
  end record regtype;

  constant reg_init_c : regtype :=
  (
    state     => IDLE_S,
    byte      => (others => '0'),
    dataOut   => (others => '0'),
    byteValid => '0',
    lowCnt    => (others => '0'),
    highCnt   => (others => '0'),
    byteCount => (others => '0'),
    waitCnt   => (others => '0'),
    biterror  => '0',
    gaperror  => '0',
    lenerror  => '0',
    disable   => '0'
  );

   signal curReg : RegType := REG_INIT_C;
   signal nxtReg : RegType := REG_INIT_C;

  signal rx_q : std_logic_vector(3 downto 0);
  signal rx_r : std_logic := '0';

  attribute shreg_extract : string;
  attribute shreg_extract of rx_q : signal is "no";


  begin

   -- Map to outputs
   rxByte      <= curReg.byte;
   rxByteValid <= curReg.byteValid;
   bitError    <= curReg.bitError;
   gapError    <= curReg.gapError;
   lenError    <= curReg.lenError;

  --  with curReg.state select rxState <=
  --       "000" when IDLE_S,   -- off
  --       "000" when DATA_S,   -- off (was red, confirmed to be working and only visible one)
  --       "010" when BIT_S,    -- blue
  --       "100" when GAP_S,    -- green
  --       "001" when FINISH_S, -- off
  --       "000" when others;   -- off

   process (clk)
  begin

    if (rising_edge (clk)) then
      rx_q <= rx_q(2 downto 0) & rx;
    end if;

  end process;

  rx_r <= rx_q(3);

  -- Asynchronous state logic
  process (curreg, rx_r, rxbyteack, disable) is
  begin

    -- Set defaults
    nxtreg <= curreg;

    nxtReg.disable <= disable;

    if (rxbyteack = '1') then
      nxtReg.byteValid <= '0';
    end if;

    if (rx_r = '1') then
      nxtReg.highCnt <= curReg.highCnt + 1;
    elsif (rx_r = '0') then
      nxtReg.lowCnt <= curReg.lowCnt + 1;
    end if;

    case(curReg.state) is

      when IDLE_S =>

        nxtReg.byteCount <= (others => '0');
        nxtReg.highCnt   <= (others => '0');
        nxtReg.waitCnt   <= (others => '0');

        if (rx_r = '1' and curReg.disable = '0') then
          nxtReg.state    <= DATA_S;
          nxtReg.lowCnt   <= (others => '0');
          nxtReg.lenError <= '0';
          nxtReg.gapError <= '0';
          nxtReg.bitError <= '0';
        end if;

      when DATA_S =>

        if (rx_r = '0') then
          nxtReg.state <= BIT_S;
        end if;

        if (curReg.highCnt > to_unsigned(N_ONE_MAX_G, 8)) then
          nxtReg.bitError <= '1';
          nxtReg.state    <= WAIT_FINISH_S;
        end if;

      when BIT_S =>

        if (curReg.highCnt >= N_ZER_MIN_G and curReg.highCnt <= N_ZER_MAX_G) then
          nxtReg.byte(to_integer(curReg.byteCount)) <= '0';
               nxtReg.state  <= GAP_S;
            elsif curReg.highCnt >= N_ONE_MIN_G and curReg.highCnt <= N_ONE_MAX_G then
          nxtReg.byte(to_integer(curReg.byteCount)) <= '1';
               nxtReg.state  <= GAP_S;
            else -- error
          nxtReg.bitError <= '1';
               nxtReg.state  <= IDLE_S;
        end if;
        nxtReg.byteCount <= curReg.byteCount + 1;
        nxtReg.highCnt <= (others => '0');

      when GAP_S =>

        if curReg.lowCnt >= N_FIN_MIN_G then
          nxtReg.state <= FINISH_S;
        end if;

        if (rx_r = '1') then
          if (curReg.lowCnt >= n_gap_min_g) then
            -- more bytes have been received than expected
            if (curReg.byteCount = num_bits_g) then
              nxtReg.lenError <= '1';
              nxtReg.state    <= IDLE_S;
            else
              nxtReg.state <= DATA_S;
            end if;
          else
            nxtReg.gapError <= '1';
            nxtReg.state    <= WAIT_FINISH_S;
          end if;
          nxtReg.lowCnt <= (others => '0');
        end if;

         when FINISH_S  =>
            if to_integer(curReg.byteCount) = NUM_BITS_G then
          nxtReg.byteValid <= '1';
        else
               -- temporarily send a bad byte just to see what we're reading if we've made it this far
               --nxtReg.byteValid <= '1';
               nxtReg.lenError  <= '1';
        end if;
        nxtReg.state <= IDLE_S;

      when WAIT_FINISH_S =>

        if (rx_r = '0') then
          nxtReg.waitCnt <= curReg.waitCnt + 1;
        else
          nxtReg.waitCnt <= (others => '0');
        end if;

        if (curReg.waitCnt >= N_FIN_MIN_G) then
          nxtReg.state <= IDLE_S;
        end if;

      when others =>

        nxtReg.state <= IDLE_S;

    end case;
  end process;

  -- Synchronous part of state machine, including reset
   process(clk) begin
    if rising_edge(clk) then
         if (sRst = '1') then
            curReg <= REG_INIT_C after GATE_DELAY_G;
      else
            curReg <= nxtReg after GATE_DELAY_G;
      end if;
    end if;
  end process;


end Behavioral;

