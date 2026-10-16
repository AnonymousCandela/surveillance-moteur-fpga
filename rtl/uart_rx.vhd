library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.package_constants.all;

entity uart_rx is

    Port(
        clk       : in  std_logic;
        reset     : in  std_logic;

        rx        : in  std_logic;

        data_out  : out std_logic_vector(7 downto 0);

        data_ready : out std_logic
    );

end uart_rx;

architecture Behavioral of uart_rx is

    constant BAUD_TICK : integer := CLOCK_FREQ / BAUD_RATE;

    type state_type is (
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    );

    signal state : state_type := IDLE;

    signal baud_counter : integer := 0;

    signal bit_counter : integer range 0 to 7 := 0;

   signal shift_reg : std_logic_vector(7 downto 0);

    -- Synchronisation du signal rx (evite la metastabilite)
    signal rx_sync1 : std_logic := '1';
    signal rx_sync2 : std_logic := '1';

begin

process(clk, reset)

begin

    if reset = '1' then

        state <= IDLE;

        baud_counter <= 0;

        bit_counter <= 0;

        shift_reg <= (others => '0');

        rx_sync1 <= '1';
        rx_sync2 <= '1';

        data_out <= (others => '0');

        data_ready <= '0';

    elsif rising_edge(clk) then

        -- Double registre de synchronisation
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;

        data_ready <= '0';

        case state is

            --------------------------------------------------
            when IDLE =>

                baud_counter <= 0;
                bit_counter <= 0;

                if rx_sync2 = '0' then
                    state <= START_BIT;
                end if;

            --------------------------------------------------
            when START_BIT =>

                if baud_counter = BAUD_TICK/2 then

                    baud_counter <= 0;

                    if rx_sync2 = '0' then
                        state <= DATA_BITS;
                    else
                        state <= IDLE;
                    end if;

                else
                    baud_counter <= baud_counter + 1;
                end if;

            --------------------------------------------------
            when DATA_BITS =>

                if baud_counter = BAUD_TICK - 1 then

                    baud_counter <= 0;

                    shift_reg(bit_counter) <= rx_sync2;

                    if bit_counter = 7 then

                        bit_counter <= 0;

                        state <= STOP_BIT;

                    else

                        bit_counter <= bit_counter + 1;

                    end if;

                else

                    baud_counter <= baud_counter + 1;

                end if;

            --------------------------------------------------
            when STOP_BIT =>

                if baud_counter = BAUD_TICK - 1 then

                    baud_counter <= 0;

                   if rx_sync2 = '1' then

                        data_out <= shift_reg;

                        data_ready <= '1';

                    end if;

                    state <= IDLE;

                else

                    baud_counter <= baud_counter + 1;

                end if;
       end case;

    end if;

end process;

end Behavioral;