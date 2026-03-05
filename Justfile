# Run integration tests against the active treb fork.
# Forwards all arguments to forge test, e.g.: just test --mc FPMMTradingLimits -vvv
test *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail

    # 1. Read FORK_URL from treb fork status (fails if no fork is running)
    FORK_URL=$(treb fork status | grep 'Fork URL:' | awk '{print $NF}')
    if [[ -z "$FORK_URL" ]]; then
        echo "Error: No active treb fork found. Run 'treb fork' first." >&2
        exit 1
    fi

    # 2. Read NETWORK and NAMESPACE from treb config
    NETWORK=$(treb config | grep 'Network:' | awk '{print $NF}')
    NAMESPACE=$(treb config | grep 'Namespace:' | awk '{print $NF}')

    # 3. Resolve the RPC URL env var name from foundry.toml (e.g. monad_testnet -> MONAD_TESTNET_RPC_URL)
    RPC_ENV_VAR=$(grep "^${NETWORK} " foundry.toml | sed 's/.*${\(.*\)}.*/\1/')
    if [[ -z "$RPC_ENV_VAR" ]]; then
        echo "Error: Could not find rpc_endpoints entry for '${NETWORK}' in foundry.toml" >&2
        exit 1
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
