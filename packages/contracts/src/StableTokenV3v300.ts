export const StableTokenV3v300 = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "disable",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "DOMAIN_SEPARATOR",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "bytes32",
          internalType: "bytes32",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "allowance",
      inputs: [
        {
          name: "owner",
          type: "address",
          internalType: "address",
        },
        {
          name: "spender",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "approve",
      inputs: [
        {
          name: "spender",
          type: "address",
          internalType: "address",
        },
        {
          name: "amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "balanceOf",
      inputs: [
        {
          name: "account",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "burn",
      inputs: [
        {
          name: "value",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "burn",
      inputs: [
        {
          name: "account",
          type: "address",
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "creditGasFees",
      inputs: [
        {
          name: "recipients",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "amounts",
          type: "uint256[]",
          internalType: "uint256[]",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "creditGasFees",
      inputs: [
        {
          name: "refundRecipient",
          type: "address",
          internalType: "address",
        },
        {
          name: "tipRecipient",
          type: "address",
          internalType: "address",
        },
        {
          name: "",
          type: "address",
          internalType: "address",
        },
        {
          name: "baseFeeRecipient",
          type: "address",
          internalType: "address",
        },
        {
          name: "refundAmount",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "tipAmount",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "baseFeeAmount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "debitGasFees",
      inputs: [
        {
          name: "from",
          type: "address",
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "decimals",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint8",
          internalType: "uint8",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "decreaseAllowance",
      inputs: [
        {
          name: "spender",
          type: "address",
          internalType: "address",
        },
        {
          name: "subtractedValue",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "deprecated_broker_storage_slot__",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "deprecated_exchange_storage_slot__",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "deprecated_validators_storage_slot__",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "increaseAllowance",
      inputs: [
        {
          name: "spender",
          type: "address",
          internalType: "address",
        },
        {
          name: "addedValue",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "initialize",
      inputs: [
        {
          name: "_name",
          type: "string",
          internalType: "string",
        },
        {
          name: "_symbol",
          type: "string",
          internalType: "string",
        },
        {
          name: "_initialOwner",
          type: "address",
          internalType: "address",
        },
        {
          name: "initialBalanceAddresses",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "initialBalanceValues",
          type: "uint256[]",
          internalType: "uint256[]",
        },
        {
          name: "_minters",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "_burners",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "_operators",
          type: "address[]",
          internalType: "address[]",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "initializeV3",
      inputs: [
        {
          name: "_minters",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "_burners",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "_operators",
          type: "address[]",
          internalType: "address[]",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "isBurner",
      inputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "isMinter",
      inputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "isOperator",
      inputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "mint",
      inputs: [
        {
          name: "to",
          type: "address",
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "name",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "nonces",
      inputs: [
        {
          name: "owner",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "owner",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "permit",
      inputs: [
        {
          name: "owner",
          type: "address",
          internalType: "address",
        },
        {
          name: "spender",
          type: "address",
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "deadline",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "v",
          type: "uint8",
          internalType: "uint8",
        },
        {
          name: "r",
          type: "bytes32",
          internalType: "bytes32",
        },
        {
          name: "s",
          type: "bytes32",
          internalType: "bytes32",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "renounceOwnership",
      inputs: [],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "returnFromPool",
      inputs: [
        {
          name: "_poolAddress",
          type: "address",
          internalType: "address",
        },
        {
          name: "_receiver",
          type: "address",
          internalType: "address",
        },
        {
          name: "_amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "sendToPool",
      inputs: [
        {
          name: "_sender",
          type: "address",
          internalType: "address",
        },
        {
          name: "_poolAddress",
          type: "address",
          internalType: "address",
        },
        {
          name: "_amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "setBurner",
      inputs: [
        {
          name: "_burner",
          type: "address",
          internalType: "address",
        },
        {
          name: "_isBurner",
          type: "bool",
          internalType: "bool",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "setMinter",
      inputs: [
        {
          name: "_minter",
          type: "address",
          internalType: "address",
        },
        {
          name: "_isMinter",
          type: "bool",
          internalType: "bool",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "setOperator",
      inputs: [
        {
          name: "_operator",
          type: "address",
          internalType: "address",
        },
        {
          name: "_isOperator",
          type: "bool",
          internalType: "bool",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "symbol",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "string",
          internalType: "string",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "totalSupply",
      inputs: [],
      outputs: [
        {
          name: "",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      stateMutability: "view",
    },
    {
      type: "function",
      name: "transfer",
      inputs: [
        {
          name: "to",
          type: "address",
          internalType: "address",
        },
        {
          name: "amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "transferFrom",
      inputs: [
        {
          name: "from",
          type: "address",
          internalType: "address",
        },
        {
          name: "to",
          type: "address",
          internalType: "address",
        },
        {
          name: "amount",
          type: "uint256",
          internalType: "uint256",
        },
      ],
      outputs: [
        {
          name: "",
          type: "bool",
          internalType: "bool",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "transferOwnership",
      inputs: [
        {
          name: "newOwner",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "event",
      name: "Approval",
      inputs: [
        {
          name: "owner",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "spender",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "BurnerUpdated",
      inputs: [
        {
          name: "burner",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "isBurner",
          type: "bool",
          indexed: false,
          internalType: "bool",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "Initialized",
      inputs: [
        {
          name: "version",
          type: "uint8",
          indexed: false,
          internalType: "uint8",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "MinterUpdated",
      inputs: [
        {
          name: "minter",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "isMinter",
          type: "bool",
          indexed: false,
          internalType: "bool",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "OperatorUpdated",
      inputs: [
        {
          name: "operator",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "isOperator",
          type: "bool",
          indexed: false,
          internalType: "bool",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "OwnershipTransferred",
      inputs: [
        {
          name: "previousOwner",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "newOwner",
          type: "address",
          indexed: true,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "Transfer",
      inputs: [
        {
          name: "from",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "to",
          type: "address",
          indexed: true,
          internalType: "address",
        },
        {
          name: "value",
          type: "uint256",
          indexed: false,
          internalType: "uint256",
        },
      ],
      anonymous: false,
    },
  ] as const,
  address: {
    143: "0x4B9B0E94197B7b2b11D311239e1420106cE7a2a2",
    10143: "0xDBd4Ea7Ce0b15C9d57DC3Fa47713477E4ef4fdcb",
    42220: "0x4B9B0E94197B7b2b11D311239e1420106cE7a2a2",
    11142220: "0xdbd4ea7ce0b15c9d57dc3fa47713477e4ef4fdcb",
  } as Partial<Record<number, `0x${string}`>>,
};
