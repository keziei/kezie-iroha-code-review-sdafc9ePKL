#!/bin/bash
# Kezie Iroha
#
# This script is designed to be sourced from .bash_profile or .bashrc
# to set up environment variables for PostgreSQL and other related tools.
# It dynamically determines PGHOME, PGDATA, PGPORT, and PGUSER based on
# the PostgreSQL installation and configuration.
# Exit if PGHOME is not found

# Load .bashrc if it exists
[ -f ~/.bashrc ] && source ~/.bashrc

# User-specific environment and startup programs
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Determine PGHOME
if command -v pg_config &>/dev/null; then
    export PGHOME=$(dirname "$(pg_config --bindir)")
else
    echo "Error: pg_config not found. PostgreSQL may not be installed."
    exit 1
fi

# Get PGDATA dynamically
export PGDATA=$(psql -d postgres -t -c "SHOW data_directory;" 2>/dev/null | xargs)
[ -z "$PGDATA" ] && export PGDATA=$(dirname "$(find /opt/homebrew /usr/local /var/lib/postgresql -name 'postgresql.conf' 2>/dev/null | head -n 1)")

# Exit if PGDATA is not found
if [ -z "$PGDATA" ]; then
    echo "Error: PGDATA could not be determined. PostgreSQL is not configured."
    exit 1
fi

# Get PGPORT from config or via SQL
export PGPORT=$(grep -E "^port" "$PGDATA/postgresql.conf" 2>/dev/null | awk '{print $3}')
[ -z "$PGPORT" ] && export PGPORT=$(psql -d postgres -t -c "SHOW port;" 2>/dev/null | xargs)

# Exit if PGPORT is missing
[ -z "$PGPORT" ] && { echo "Error: PGPORT could not be determined."; exit 1; }

# Get PGUSER dynamically
export PGUSER=$(psql -d postgres -t -c "SELECT current_user;" 2>/dev/null | xargs)
[ -z "$PGUSER" ] && { echo "Error: PGUSER could not be determined."; exit 1; }

# Display all databases before selecting PGDATABASE
echo -e "\n  Available Databases (from oid2name)\n  --------------------------------------"
if command -v oid2name &>/dev/null; then
    oid2name | awk 'NR>3 {print $2}' | column
else
    echo "oid2name command not found."
fi
echo ""

# Get PGDATABASE by selecting the lowest OID
export PGDATABASE=$(oid2name | awk 'NR>3 && $2 != "template0" && $2 != "template1" {print $1, $2}' | sort -n | awk 'NR==1 {print $2}')
[ -z "$PGDATABASE" ] && { echo "Error: PGDATABASE could not be determined."; exit 1; }

# Derive config file paths
export PGCONF="$PGDATA/postgresql.conf"
export PG_HBA="$PGDATA/pg_hba.conf"

# Add PostgreSQL binaries to PATH
[ -d "$PGHOME/bin" ] && export PATH="$PGHOME/bin:$PATH"

# Check if PostgreSQL is running
PGSTATUS=$(pg_ctl status 2>/dev/null)
POSTGRES_RUNNING=false
if echo "$PGSTATUS" | grep -q "server is running"; then
    POSTGRES_RUNNING=true
fi

# Display environment summary
echo -e "\n  PostgreSQL Environment\n  ----------------------"
echo -e "  PGHOME     = $PGHOME\n  PGDATA     = $PGDATA\n  PGPORT     = $PGPORT"
echo -e "  PGUSER     = $PGUSER\n  PGDATABASE = $PGDATABASE\n  PGCONF     = $PGCONF\n  PG_HBA     = $PG_HBA\n"

# Display PostgreSQL status
echo "  PostgreSQL Server Status\n  ----------------------"
$POSTGRES_RUNNING && echo "$PGSTATUS" || echo "PostgreSQL is installed but not running."
echo ""

# Only display the `oid2name` reminder if PostgreSQL is running
$POSTGRES_RUNNING && echo "🔹 To list all databases on this server, enter: oid2name"
