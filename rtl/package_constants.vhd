library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package package_constants is

    --------------------------------------------------------------------
    -- Horloge de la carte DE1-SoC
    --------------------------------------------------------------------
    constant CLOCK_FREQ : integer := 50_000_000;

    --------------------------------------------------------------------
    -- Configuration UART
    --------------------------------------------------------------------
    constant BAUD_RATE : integer := 115_200;

    constant UART_START : std_logic_vector(7 downto 0) := x"AA";
    constant UART_STOP  : std_logic_vector(7 downto 0) := x"55";

    --------------------------------------------------------------------
    -- États internes du système
    --------------------------------------------------------------------
    type motor_state_t is (
        NORMAL,
        DEGRADE,
        FAULT
    );

    --------------------------------------------------------------------
    -- Codes transmis à l’Arduino
    --------------------------------------------------------------------
    constant STATE_NORMAL_CODE  : std_logic_vector(7 downto 0) := x"01";
    constant STATE_DEGRADE_CODE : std_logic_vector(7 downto 0) := x"02";
    constant STATE_FAULT_CODE   : std_logic_vector(7 downto 0) := x"03";

    --------------------------------------------------------------------
    -- Seuils de vitesse
    --------------------------------------------------------------------
    constant RPM_FAULT_LIMIT : unsigned(15 downto 0)
        := to_unsigned(99, 16);

    constant RPM_NORMAL_MIN : unsigned(15 downto 0)
        := to_unsigned(190, 16);

    constant RPM_NORMAL_MAX : unsigned(15 downto 0)
        := to_unsigned(240, 16);

    constant RPM_DEGRADE_MIN : unsigned(15 downto 0)
        := to_unsigned(100, 16);

    constant RPM_DEGRADE_MAX : unsigned(15 downto 0)
        := to_unsigned(189, 16);

    --------------------------------------------------------------------
    -- Seuils de courant
    --------------------------------------------------------------------
    constant CURRENT_FAULT_LIMIT : unsigned(15 downto 0)
        := to_unsigned(2000, 16);

    constant CURRENT_NORMAL_MIN : unsigned(15 downto 0)
        := to_unsigned(200, 16);

    constant CURRENT_NORMAL_MAX : unsigned(15 downto 0)
        := to_unsigned(624, 16);

    constant CURRENT_DEGRADE_MIN : unsigned(15 downto 0)
        := to_unsigned(644, 16);

    constant CURRENT_DEGRADE_MAX : unsigned(15 downto 0)
        := to_unsigned(1999, 16);

    --------------------------------------------------------------------
    -- Nombre de mesures consécutives avant confirmation d’un état
    --------------------------------------------------------------------
    constant CONFIRM_COUNT : positive := 3;

end package package_constants;

package body package_constants is
end package body package_constants;