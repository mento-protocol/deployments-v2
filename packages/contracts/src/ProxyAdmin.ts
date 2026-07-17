export const ProxyAdmin = {
  abi: [
    {
      type: "constructor",
      inputs: [
        {
          name: "initialOwner",
          type: "address",
          internalType: "address",
        },
      ],
      stateMutability: "nonpayable",
    },
    {
      type: "function",
      name: "UPGRADE_INTERFACE_VERSION",
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
      name: "renounceOwnership",
      inputs: [],
      outputs: [],
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
      name: "upgradeAndCall",
      inputs: [
        {
          name: "proxy",
          type: "address",
          internalType: "contract ITransparentUpgradeableProxy",
        },
        {
          name: "implementation",
          type: "address",
          internalType: "address",
        },
        {
          name: "data",
          type: "bytes",
          internalType: "bytes",
        },
      ],
      outputs: [],
      stateMutability: "payable",
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
      type: "error",
      name: "OwnableInvalidOwner",
      inputs: [
        {
          name: "owner",
          type: "address",
          internalType: "address",
        },
      ],
    },
    {
      type: "error",
      name: "OwnableUnauthorizedAccount",
      inputs: [
        {
          name: "account",
          type: "address",
          internalType: "address",
        },
      ],
    },
  ] as const,
  address: {
    137: "0xf759073E3a6125fFF215427AeB313A49799FECCf",
    143: "0xf759073E3a6125fFF215427AeB313A49799FECCf",
    10143: "0xaad8b67551086609D132178dfF1dBE31b3c1C9C2",
    42220: "0x70d8DC60f9701c46D4CE9AC141E154f6804e1dC3",
    80002: "0xaad8b67551086609D132178dfF1dBE31b3c1C9C2",
    84532: "0xaad8b67551086609D132178dfF1dBE31b3c1C9C2",
    11142220: "0x01bd47aa7B13a75c24E3dA760f8A503c435BB4Df",
  } as Partial<Record<number, `0x${string}`>>,
};
