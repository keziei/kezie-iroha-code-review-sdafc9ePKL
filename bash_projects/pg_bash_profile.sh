#!/bin/bash
# Kezie Iroha
#
# This script is designed to be sourced from .bash_profile or .bashrc
# to set up environment variables for PostgreSQL and other related tools.
# It dynamically determines PGHOME, PGDATA, PGPORT, and PGUSER based on
# the PostgreSQL installation and configuration.
# Exit if PGHOME is not found

# Load .bashrc if it exists
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# User-specific environment and startup programs
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# Determine PGHOME (PostgreSQL installation directory)
if command -v pg_config &>/dev/null; then
    export PGHOME=$(dirname "$(pg_config --bindir)")
else
    echo "Error: pg_config not found. PostgreSQL may not be installed."
    exit 1
fi

# Attempt to retrieve PGDATA from a running PostgreSQL instance
if command -v psql &>/dev/null; then
    PGDATA=$(psql -d postgres -t -c "SHOW data_directory;" 2>/dev/null | xargs)
fi

# If PGDATA is still empty, try to find postgresql.conf manually
if [ -z "$PGDATA" ]; then
    PGDATA=$(dirname "$(find /opt/homebrew /usr/local /var/lib/postgresql -name "postgresql.conf" 2>/dev/null | head -n 1)")
fi

# If PGDATA is still empty, exit as PostgreSQL is not configured
if [ -z "$PGDATA" ]; then
    echo "Error: PGDATA directory could not be determined. PostgreSQL is not configured on this system."
    exit 1
fi

export PGDATA

# Determine PGPORT from postgresql.conf or via SQL
if [ -f "$PGDATA/postgresql.conf" ]; then
    PGPORT=$(grep -E "^port" "$PGDATA/postgresql.conf" 2>/dev/null | awk '{print $3}')
fi

# If PGPORT is empty, attempt to retrieve it via psql
if [ -z "$PGPORT" ] && command -v psql &>/dev/null; then
    PGPORT=$(psql -d postgres -t -c "SHOW port;" 2>/dev/null | xargs)
fi

# If PGPORT is still empty, exit
if [ -z "$PGPORT" ]; then
    echo "Error: Could not determine PGPORT from postgresql.conf or database query."
    exit 1
fi

export PGPORT

# Determine PGUSER dynamically
PGUSER=$(psql -d postgres -t -c "SELECT current_user;" 2>/dev/null | xargs)

# If PGUSER is empty, exit
if [ -z "$PGUSER" ]; then
    echo "Error: Could not determine PGUSER from PostgreSQL."
    exit 1
fi

export PGUSER

# Display all databases before selecting PGDATABASE
echo ""
echo "  Available Databases (from oid2name)"
echo "  --------------------------------------"
if command -v oid2name &>/dev/null; then
    oid2name | awk 'NR>3 {print $2}' | column
else
    echo "oid2name command not found."
fi
echo ""

# Determine PGDATABASE dynamically by selecting the database with the lowest OID
if command -v oid2name &>/dev/null && [ -d "$PGDATA" ]; then
    PGDATABASE=$(oid2name | awk 'NR>3 && $2 != "template0" && $2 != "template1" {print $1, $2}' | sort -n | awk 'NR==1 {print $2}')
fi

# If PGDATABASE is still empty, exit
if [ -z "$PGDATABASE" ]; then
    echo "Error: Could not determine PGDATABASE. No user-created databases found."
    exit 1
fi

export PGDATABASE

# Derive PGCONF and PG_HBA from PGDATA
export PGCONF="$PGDATA/postgresql.conf"
export PG_HBA="$PGDATA/pg_hba.conf"

# Add PostgreSQL binaries to PATH safely
if [ -d "$PGHOME/bin" ]; then
    export PATH="$PGHOME/bin:$PATH"
fi

# Check if PostgreSQL is properly configured
if [ ! -d "$PGDATA" ]; then
    echo "Error: PGDATA directory ($PGDATA) does not exist. PostgreSQL is not configured properly."
    exit 1
fi

# Prompt customization
export PS1='\u:\w$ '

# Display environment summary
echo ""
echo "  PostgreSQL Environment"
echo "  ----------------------"
echo "  PGHOME     = $PGHOME"
echo "  PGDATA     = $PGDATA"
echo "  PGPORT     = $PGPORT"
echo "  PGUSER     = $PGUSER"
echo "  PGDATABASE = $PGDATABASE"
echo "  PGCONF     = $PGCONF"
echo "  PG_HBA     = $PG_HBA"

# Check PostgreSQL status only if configured
echo ""
echo "  PostgreSQL Server Status"
echo "  ----------------------"
if command -v pg_ctl &>/dev/null; then
    PGSTATUS=$(pg_ctl status 2>/dev/null)
    if echo "$PGSTATUS" | grep -q "server is running"; then
        echo "$PGSTATUS"
        POSTGRES_RUNNING=true
    else
        echo "PostgreSQL is installed but not running."
        POSTGRES_RUNNING=false
    fi
else
    echo "PostgreSQL is not installed or pg_ctl not found in PATH."
    POSTGRES_RUNNING=false
fi
echo ""

# Only display the oid2name reminder if PostgreSQL is properly running
if [ "$POSTGRES_RUNNING" = true ]; then
    echo "🔹 To list all databases on this server, enter: oid2name"
    echo ""
fi
