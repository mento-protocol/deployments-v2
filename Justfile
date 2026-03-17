# Run integration tests against the active treb fork.
# Forwards all arguments to forge test, e.g.: just test --mc FPMMTradingLimits -vvv
test *ARGS:
    #!/usr/bin/env bash

    set -a; source .env 2>/dev/null; set +a

    # 1. Read NETWORK and NAMESPACE from treb config
    NETWORK=$(treb config | grep 'Network:' | awk '{print $NF}')
    NAMESPACE=$(treb config | grep 'Namespace:' | awk '{print $NF}')

    # 2. Resolve the RPC URL env var name from foundry.toml (e.g. monad_testnet -> MONAD_TESTNET_RPC_URL)
    RPC_ENV_VAR=$(grep "^${NETWORK} " foundry.toml | head -1 | sed 's/.*${\(.*\)}.*/\1/')
    if [[ -z "$RPC_ENV_VAR" ]]; then
        echo "Error: Could not find rpc_endpoints entry for '${NETWORK}' in foundry.toml" >&2
        exit 1
    fi

    # 3. Read FORK_URL from treb fork status, falling back to the network's RPC URL
    FORK_URL=$(treb fork status | grep 'Fork URL:' | awk '{print $NF}' || true)
    if [[ -z "$FORK_URL" ]]; then
        FORK_URL="${!RPC_ENV_VAR}"
        if [[ -z "$FORK_URL" ]]; then
            echo "Error: No active treb fork and ${RPC_ENV_VAR} is not set." >&2
            exit 1
        fi
        echo "No active fork, using ${RPC_ENV_VAR} as FORK_URL"
    fi

    # 4. Export everything and run forge test
    export FORK_URL NETWORK NAMESPACE
    export "${RPC_ENV_VAR}=${FORK_URL}"

    echo "FORK_URL=$FORK_URL"
    echo "NETWORK=$NETWORK"
    echo "NAMESPACE=$NAMESPACE"
    echo "${RPC_ENV_VAR}=$FORK_URL"
    echo ""

    forge test {{ARGS}}

# Print all environment variables as export statements (useful for eval $(just env))
env:
    #!/usr/bin/env bash
    set -euo pipefail

    set -a; source .env 2>/dev/null; set +a

    NETWORK=$(treb config | grep 'Network:' | awk '{print $NF}')
    NAMESPACE=$(treb config | grep 'Namespace:' | awk '{print $NF}')

    RPC_ENV_VAR=$(grep "^${NETWORK} " foundry.toml | head -1 | sed 's/.*${\(.*\)}.*/\1/')

    FORK_URL=$(treb fork status | grep 'Fork URL:' | awk '{print $NF}' || true)

    if [[ -z "$FORK_URL" ]]; then
        FORK_URL="${!RPC_ENV_VAR}"
    fi

    echo "export FORK_URL=$FORK_URL"
    echo "export NETWORK=$NETWORK"
    echo "export NAMESPACE=$NAMESPACE"
    if [[ -n "$RPC_ENV_VAR" ]]; then
        echo "export ${RPC_ENV_VAR}=$FORK_URL"
    fi
