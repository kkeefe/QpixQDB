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
library ice;
use ice.all;

entity QDBFifo is

  generic (
    read_mode  : std_ulogic := '0';
    write_mode : std_ulogic := '0';
    RAM_TYPE   : string := "block";
    DATA_WIDTH : natural := 16;
    DEPTH      : natural := G_FIFO_LOC_DEPTH
    );

  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    -- bram ports
    din   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    wen   : in  std_logic;
    ren   : in  std_logic;
    dout  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    empty : out std_logic;
    full  : out std_logic
    );

end entity QDBFifo;


architecture Behavioral of QDBFifo is

   signal i_ren       : std_logic;
   signal i_full      : std_logic;
   signal i_empty     : std_logic;
   signal i_empty_r   : std_logic;
   signal i_waddr     : std_logic_vector(DEPTH-1 downto 0) := (others => '0');
   signal i_raddr     : std_logic_vector(DEPTH-1 downto 0) := (others => '0');
   signal i_cnt       : std_logic_vector(DEPTH-1 downto 0) := (others => '0');

  -- design copied from mem.vhd fifo_cc
   constant MAX_ADDR  : std_logic_vector(DEPTH-1 downto 0) := (others =>'1');
   constant ZERO_ADDR : std_logic_vector(DEPTH-1 downto 0) := (others =>'0');

   -- how many 256x16 BRAMs are required??
   constant BRAM_WIDTH : natural := DATA_WIDTH / 16;
   constant BRAM_DEPTH : natural := DEPTH / 256;

component SB_RAM256x16
GENERIC(
    read_mode  : std_logic;
    write_mode : std_logic
);
PORT(
    wdata : in std_logic_vector(15 downto 0);
    mask  : in std_logic_vector(15 downto 0);
    waddr : in std_logic_vector(DEPTH-1 downto 0);
    we    : in std_logic;
    wclke : in std_logic;
    wclk  : in std_logic;
    rdata : out std_logic_vector(15 downto 0);
    raddr : in std_logic_vector(DEPTH-1 downto 0);
    rclke : in std_logic;
    rclk  : in std_logic;
    re    : in std_logic
);
END COMPONENT;

begin

   -- Use the Lattice RAM
   p_ram: for x in 0 to BRAM_WIDTH - 1 generate
     ram40_4kinst_physical : SB_RAM256x16
       generic map(
        read_mode  => read_mode,
        write_mode => write_mode)
       port map(
         -- write
         wdata => din(x*16+15 downto x*16),
         mask  => (others => '0'),
         waddr => i_waddr,
         we    => wen,
         wclke => '1',
         wclk  => clk,
         -- read
         rdata => dout(x*16+15 downto x*16),
         raddr => i_raddr,
         rclke => '1',
         rclk  => clk,
         re    => i_ren);
   end generate p_ram;
   ---------------------------------------------------

   ---- generate full and empty signals
   i_full   <= '1' when i_cnt = MAX_ADDR  else '0';
   i_empty  <= '1' when i_cnt = ZERO_ADDR else '0';
   full     <= i_full;
   empty    <= i_empty or i_empty_r;
   i_ren <= ren;

   ---- count number of words in FIFO
   FIFO_CNT_PROC : process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            i_cnt <= (others => '0');
         else
            if wen = '1' and i_ren = '0' and i_full = '0' then
               i_cnt <= i_cnt + '1';
            elsif wen = '0' and i_ren = '1' and i_empty = '0' then
               i_cnt <= i_cnt - '1';
            end if;
         end if;
      end if;
   end process FIFO_CNT_PROC;
   ----

   ---- manage read/write addresses for BRAM
   RW_ADDR_PROC : process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            i_waddr <= (others => '0');
            i_raddr <= (others => '0');
         else
            if (wen = '1' and i_full = '0') then
               if i_waddr = MAX_ADDR then
                  i_waddr <= (others => '0');
               else
                  i_waddr <= i_waddr + 1;
               end if;
            end if;

            if (i_ren = '1' and i_empty = '0') then
               if i_raddr = MAX_ADDR then
                  i_raddr <= (others => '0');
               else
                  i_raddr <= i_raddr + 1;
               end if;
            end if;

         end if;
      end if;
   end process RW_ADDR_PROC;

end Behavioral;
