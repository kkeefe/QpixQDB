library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity QDBLed is
   generic (
      PWM_BITS     : natural := 8;
      pulse_time   : natural := 9_999_999
    );
port (
    -- internal clock
    clk : in STD_LOGIC;
    rst : in STD_LOGIC;

    cond_red_led : in boolean;
    cond_gre_led : in boolean;
    cond_blu_led : in boolean;

    -- outputs
    red_led : out STD_LOGIC;
    blu_led : out STD_LOGIC;
    gre_led : out STD_LOGIC
    );

end QDBLed;


architecture Behavioral of QDBLed is

  signal b_red_led  : boolean := false;
  signal b_blu_led  : boolean := false;
  signal b_gre_led  : boolean := false;

  signal pulse_red     : std_logic := '0';
  signal pulse_blu     : std_logic := '0';
  signal pulse_gre     : std_logic := '0';

  signal pulse_red_buf : std_logic := '0';
  signal pulse_blu_buf : std_logic := '0';
  signal pulse_gre_buf : std_logic := '0';

  signal slv_led_buf   : std_logic_vector(2 downto 0);

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

   procedure pwm(variable count : inout unsigned(PWM_BITS-1 downto 0);
                 signal input : in std_logic;
                 signal output : out std_logic) is
      begin
         if input = '1' then
             count := count + 1;
             if count(PWM_BITS-1) = '1' then
                output <= '1';
                count := (others => '0');
             else
               output <= '0';
             end if;
         else
           count := (others => '0');
           output <= '0';
         end if;
      end procedure pwm;

-----------------------------ARCH------------------------------------------
begin

    process(clk) is
       variable cr5             : boolean                       := false;
       variable cb5             : boolean                       := false;
       variable cg5             : boolean                       := false;
       variable pulse_count_red : integer range 0 to pulse_time := 0;
       variable start_pulse_red : std_logic                     := '0';
       variable pulse_count_gre : integer range 0 to pulse_time := 0;
       variable start_pulse_gre : std_logic                     := '0';
       variable pulse_count_blu : integer range 0 to pulse_time := 0;
       variable start_pulse_blu : std_logic                     := '0';
       -- pwm variables
       variable pwm_red : unsigned(PWM_BITS-1 downto 0) := (others => '0');
       variable pwm_gre : unsigned(PWM_BITS-1 downto 0) := (others => '0');
       variable pwm_blu : unsigned(PWM_BITS-1 downto 0) := (others => '0');
    begin
     if rising_edge(clk) then

        --flash LED conditions for Rx and Tx
        cr5 := b_red_led;
        cg5 := b_gre_led;
        cb5 := b_blu_led;
        b_red_led <= cond_red_led;
        b_gre_led <= cond_gre_led;
        b_blu_led <= cond_blu_led;

        pulseLED(cr5, start_pulse_red, pulse_count_red, pulse_red);
        pulseLED(cg5, start_pulse_gre, pulse_count_gre, pulse_gre);
        pulseLED(cb5, start_pulse_blu, pulse_count_blu, pulse_blu);

        slv_led_buf <= pulse_blu & pulse_gre & pulse_red;

        pulse_red_buf <= slv_led_buf(0);
        pulse_gre_buf <= slv_led_buf(1);
        pulse_blu_buf <= slv_led_buf(2);

        pwm(pwm_red, pulse_red_buf, red_led);
        pwm(pwm_gre, pulse_gre_buf, gre_led);
        pwm(pwm_blu, pulse_blu_buf, blu_led);

        end if;
    end process;

end Behavioral;
