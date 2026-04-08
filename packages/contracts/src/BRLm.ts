export const BRLm = {
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
      name: "broker",
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
      name: "creditGasFees",
      inputs: [
        {
          name: "from",
          type: "address",
          internalType: "address",
        },
        {
          name: "feeRecipient",
          type: "address",
          internalType: "address",
        },
        {
          name: "gatewayFeeRecipient",
          type: "address",
          internalType: "address",
        },
        {
          name: "communityFund",
          type: "address",
          internalType: "address",
        },
        {
          name: "refund",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "tipTxFee",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "gatewayFee",
          type: "uint256",
          internalType: "uint256",
        },
        {
          name: "baseTxFee",
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
      name: "exchange",
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
          name: "initialBalanceAddresses",
          type: "address[]",
          internalType: "address[]",
        },
        {
          name: "initialBalanceValues",
          type: "uint256[]",
          internalType: "uint256[]",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "initializeV2",
      inputs: [
        {
          name: "_broker",
          type: "address",
          internalType: "address",
        },
        {
          name: "_validators",
          type: "address",
          internalType: "address",
        },
        {
          name: "_exchange",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
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
      name: "setBroker",
      inputs: [
        {
          name: "_broker",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "setExchange",
      inputs: [
        {
          name: "_exchange",
          type: "address",
          internalType: "address",
        },
      ],
      outputs: [],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "setValidators",
      inputs: [
        {
          name: "_validators",
          type: "address",
          internalType: "address",
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
      type: "function",
      name: "transferWithComment",
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
        {
          name: "comment",
          type: "string",
          internalType: "string",
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
      name: "validators",
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
      name: "BrokerUpdated",
      inputs: [
        {
          name: "broker",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "ExchangeUpdated",
      inputs: [
        {
          name: "exchange",
          type: "address",
          indexed: false,
          internalType: "address",
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
    {
      type: "event",
      name: "TransferComment",
      inputs: [
        {
          name: "comment",
          type: "string",
          indexed: false,
          internalType: "string",
        },
      ],
      anonymous: false,
    },
    {
      type: "event",
      name: "ValidatorsUpdated",
      inputs: [
        {
          name: "validators",
          type: "address",
          indexed: false,
          internalType: "address",
        },
      ],
      anonymous: false,
    },
  ] as const,
  address: {
    42220: "0xe8537a3d056da446677b9e9d6c5db704eaab4787",
    11142220: "0x2294298942fdc79417DE9E0D740A4957E0e7783a",
  } as Partial<Record<number, `0x${string}`>>,
  decimals: 18,
};
